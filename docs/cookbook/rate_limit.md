# Rate Limit

Password reset endpoints are cheap to call and expensive to abuse — mail floods, support tickets, angry users.

Cap how many times a task may run per window per actor. Middleware increments a counter in [`CMDx::Stores`](../stores.md) and halts with `fail!` before `work` when the bucket is full. Configure Redis (or similar) in production via `CMDx.configuration.store`.

## Setup

```ruby
class CmdxRateLimitMiddleware
  def initialize(max:, per:, key: :class, prefix: "rl")
    @max    = max
    @per    = per
    @key    = key
    @prefix = prefix
  end

  def call(task)
    bucket = resolve_key(task)
    count  = CMDx::Stores.incr("#{@prefix}:#{bucket}", ttl: @per)

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
result.failed?                # => true
result.reason                 # => "rate limited: 6/5 per 60s for user@example.com"
result.metadata[:code]        # => :rate_limited
result.metadata[:retry_after] # => 60
```

## Notes

### Fixed-window vs token-bucket

`incr` + TTL is a fixed window — simple and fast, but a burst can slip through at the window boundary. For smoother shaping, swap the counter logic; keep halting from middleware with `fail!` or `skip!`.

### Skip vs fail

`fail!` marks throttled calls as rejected (handy for HTTP 429). Use `task.skip!(...)` when excess calls should disappear quietly.

### Keying strategies

`:class` throttles globally per task. A Symbol reads `task.context[symbol]` — often `:user_id` or `:ip_address`. A Proc composes dimensions: `->(t) { "#{t.context.user_id}:#{t.context.endpoint}" }`.
