# Redis Idempotency

Guard non-idempotent operations (charging a card, sending an email) by recording a Redis key around the task and refusing duplicates.

## Setup

```ruby
# app/middlewares/cmdx_redis_idempotency_middleware.rb
class CmdxRedisIdempotencyMiddleware
  def initialize(key:, ttl: 300)
    @key = key
    @ttl = ttl
  end

  def call(task)
    redis_key = "cmdx:idempotency:#{task.class.name}:#{resolve_id(task)}"

    if Redis.current.set(redis_key, "processing", nx: true, ex: @ttl)
      begin
        yield
        Redis.current.set(redis_key, "done", xx: true, ex: @ttl)
      rescue StandardError
        Redis.current.del(redis_key)
        raise
      end
    else
      task.errors.add(:base, "duplicate request (state=#{Redis.current.get(redis_key)})")
      yield
    end
  end

  private

  def resolve_id(task)
    case @key
    when Symbol then task.send(@key)
    when Proc   then @key.call(task)
    else             task.context[@key]
    end
  end
end
```

## Usage

```ruby
class ChargeCustomer < CMDx::Task
  register :middleware, CmdxRedisIdempotencyMiddleware.new(key: ->(t) { t.context[:payment_id] })

  required :payment_id

  def work
    # ...
  end
end

ChargeCustomer.execute(payment_id: "pay_123")  # first call -> success
ChargeCustomer.execute(payment_id: "pay_123")  # second call -> failed ("duplicate request ...")
```

## Notes

!!! warning "Important"

    A middleware cannot emit a `skipped` signal — that must originate inside `work`. This middleware surfaces duplicates as **failed** results by appending to `task.errors` before `yield`, so `signal_errors!` halts during input resolution with a clear reason.

!!! tip

    To treat duplicates as *skipped* instead of *failed*, move the Redis check into `work` and call `skip!("duplicate")`. See [Outcomes — Annotating a Successful Result](../docs/outcomes/result.md#annotating-a-successful-result) for the `skip!` / `success!` / `fail!` mechanics.
