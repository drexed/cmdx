# Rate Limit

A password-reset endpoint is a textbook abuse target: cheap to call, expensive downstream (mail delivery, account lockout). Capping it at *N* invocations per window per actor turns a flood into a handful of failed results without the task ever reaching `work`.

## Setup

The middleware increments a counter in a pluggable store and, when the bucket is full, halts the task with `fail!` before `work` runs.

```ruby
# app/middlewares/cmdx_rate_limit_middleware.rb
# frozen_string_literal: true

class CmdxRateLimitMiddleware
  def initialize(max:, per:, key: :class, store: MemoryStore.new)
    @max   = max
    @per   = per
    @key   = key
    @store = store
  end

  def call(task)
    bucket = resolve_key(task)
    count  = @store.increment(bucket, ttl: @per)

    if count > @max
      task.send(
        :fail!,
        "rate limited: #{count}/#{@max} per #{@per}s for #{bucket}",
        code: :rate_limited,
        retry_after: @per
      )
    end

    yield
  end

  private

  def resolve_key(task)
    case @key
    when :class then task.class.name
    when Symbol then task.context[@key].to_s
    when Proc   then @key.call(task).to_s
    else             @key.to_s
    end
  end

  class MemoryStore
    def initialize
      @mutex = Mutex.new
      @data  = {}
    end

    def increment(key, ttl:)
      @mutex.synchronize do
        now    = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        bucket = @data[key]

        if bucket.nil? || bucket[:exp] < now
          @data[key] = { count: 1, exp: now + ttl }
          1
        else
          bucket[:count] += 1
        end
      end
    end
  end
end
```

## Usage

```ruby
class SendPasswordReset < CMDx::Task
  register :middleware, CmdxRateLimitMiddleware.new(
    max: 5,
    per: 60,
    key: ->(task) { task.context.email }
  )

  required :email, coerce: :string

  def work
    Mailer.password_reset(email).deliver_later
  end
end

5.times { SendPasswordReset.execute(email: "user@example.com") }   # success
result = SendPasswordReset.execute(email: "user@example.com")
result.failed?              # => true
result.reason               # => "rate limited: 6/5 per 60s for user@example.com"
result.metadata[:code]      # => :rate_limited
result.metadata[:retry_after] # => 60
```

## Redis store

The in-memory store resets per process. A shared store backs the same middleware across workers and hosts; the Lua script makes the `INCR` + `EXPIRE` pair atomic so the first caller in each window is the one that sets the TTL.

```ruby
# app/middlewares/cmdx_rate_limit_middleware/redis_store.rb
# frozen_string_literal: true

class CmdxRateLimitMiddleware
  class RedisStore
    INCR_WITH_TTL = <<~LUA
      local count = redis.call("INCR", KEYS[1])
      if count == 1 then redis.call("EXPIRE", KEYS[1], ARGV[1]) end
      return count
    LUA
    private_constant :INCR_WITH_TTL

    def initialize(redis: Redis.current, namespace: "cmdx:rl")
      @redis     = redis
      @namespace = namespace
    end

    def increment(key, ttl:)
      @redis.eval(INCR_WITH_TTL, keys: ["#{@namespace}:#{key}"], argv: [ttl])
    end
  end
end

register :middleware, CmdxRateLimitMiddleware.new(
  max: 100, per: 60,
  key:   ->(t) { t.context.user_id },
  store: CmdxRateLimitMiddleware::RedisStore.new
)
```

## Notes

!!! note "Fixed-window vs token-bucket"

    A fixed window is simple and fast but allows a 2× burst at the boundary (last second of window N + first second of window N+1). For smoother shaping, swap the store for a token-bucket implementation — the middleware contract (`#increment(key, ttl:) → Integer`) is unchanged.

!!! tip "Skip vs fail"

    `fail!` flags throttled calls as actively rejected (handy for surfacing 429s). Swap to `task.skip!(...)` when excess calls should be silently dropped — both signals are valid from a middleware.

!!! tip "Keying strategies"

    `:class` throttles globally per task. A Symbol reads `task.context[symbol]` — typically `:user_id`, `:ip_address`, `:account_id`. A Proc composes multiple dimensions: `->(t) { "#{t.context.user_id}:#{t.context.endpoint}" }` for a user-and-endpoint bucket.
