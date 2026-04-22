# Rate Limit

Throttle a task so a burst of callers can't exceed `N` executions per window. The middleware increments a counter in a pluggable store; when the window is full it records a clear error and `yield`s, letting `signal_errors!` halt the task as **failed** during input resolution.

## Setup

```ruby
# app/middlewares/cmdx_rate_limit_middleware.rb
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
      task.errors.add(:base, "rate limited: #{count}/#{@max} per #{@per}s for #{bucket}")
    end

    yield
  end

  private

  def resolve_key(task)
    case @key
    when :class then task.class.name
    when Symbol then task.send(@key).to_s
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
    key: ->(t) { t.context.email }
  )

  required :email

  def work
    Mailer.password_reset(email).deliver_later
  end
end

5.times { SendPasswordReset.execute(email: "user@example.com") }   # success
SendPasswordReset.execute(email: "user@example.com")               # failed:
#   reason => "rate limited: 6/5 per 60s for user@example.com"
```

## Redis store

The in-memory store resets per process. For production (multi-worker / multi-host), back it with Redis using an atomic `INCR` + `EXPIRE` pair (Lua script avoids a race between the two commands):

```ruby
class RedisRateStore
  LUA = <<~LUA.freeze
    local c = redis.call("INCR", KEYS[1])
    if c == 1 then redis.call("EXPIRE", KEYS[1], ARGV[1]) end
    return c
  LUA

  def initialize(redis: Redis.current, namespace: "cmdx:rl")
    @redis     = redis
    @namespace = namespace
  end

  def increment(key, ttl:)
    @redis.eval(LUA, keys: ["#{@namespace}:#{key}"], argv: [ttl])
  end
end

register :middleware, CmdxRateLimitMiddleware.new(
  max: 100, per: 60, key: ->(t) { t.context.user_id }, store: RedisRateStore.new
)
```

## Notes

!!! note "Fixed-window vs token-bucket"

    The example uses a fixed window: the counter resets when the TTL expires. That's simple and fast but allows brief 2× bursts at window boundaries (last second of window N + first second of window N+1). For smoother shaping, replace the store with a token-bucket implementation — the middleware contract is unchanged.

!!! warning "Failed, not skipped"

    A middleware cannot emit a `skipped` signal — that originates inside `work`. This middleware surfaces throttling as **failed** via `task.errors` + `yield`, letting `signal_errors!` halt during input resolution. To treat excess calls as *skipped* instead, hoist the rate-limit check into `work` and call `skip!("rate limited")`.

!!! tip "Keying strategies"

    Pick the `:key` to match your threat model: `:class` throttles globally per task, a Symbol reads an attribute (`:user_id`, `:ip`), a Proc composes multiple dimensions (`->(t) { "#{t.context.user_id}:#{t.context.endpoint}" }`).
