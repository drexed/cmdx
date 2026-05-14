# Redis Idempotency

A retried webhook, a double-clicked checkout button, a Sidekiq job redelivered after a deploy — all three call the same task twice with the same payload. For non-idempotent operations (charging a card, sending an email) the second call must be rejected, not re-executed. A short-lived Redis key keyed on the operation's natural id is the smallest correct lock.

## Setup

```ruby
# app/middlewares/cmdx_redis_idempotency_middleware.rb
# frozen_string_literal: true

class CmdxRedisIdempotencyMiddleware
  PROCESSING = "processing"
  DONE       = "done"
  private_constant :PROCESSING, :DONE

  def initialize(key:, ttl: 300, redis: Redis.current, namespace: "cmdx:idem")
    @key       = key
    @ttl       = ttl
    @redis     = redis
    @namespace = namespace
  end

  def call(task)
    redis_key = "#{@namespace}:#{task.class.name}:#{resolve_id(task)}"

    if @redis.set(redis_key, PROCESSING, nx: true, ex: @ttl)
      begin
        yield
        @redis.set(redis_key, DONE, xx: true, ex: @ttl)
      rescue StandardError
        @redis.del(redis_key)
        raise
      end
    else
      state = @redis.get(redis_key)
      task.send(
        :skip!,
        "duplicate request (state=#{state})",
        code: :duplicate,
        idempotency_key: redis_key
      )
    end
  end

  private

  def resolve_id(task)
    case @key
    when Symbol then task.context[@key]
    when Proc   then @key.call(task)
    else             @key
    end
  end
end
```

## Usage

```ruby
class ChargeCustomer < CMDx::Task
  register :middleware, CmdxRedisIdempotencyMiddleware.new(key: :payment_id)

  required :payment_id,   coerce: :string
  required :amount_cents, coerce: :integer

  def work
    context.charge = Stripe::Charge.create(
      amount:           amount_cents,
      currency:         "usd",
      idempotency_key:  payment_id
    )
  end
end

ChargeCustomer.execute(payment_id: "pay_123", amount_cents: 9_900) # success
ChargeCustomer.execute(payment_id: "pay_123", amount_cents: 9_900) # skipped: duplicate
```

## Notes

!!! tip "Skip vs fail"

    `skip!` produces a `skipped?` result — appropriate for idempotent no-ops where the second call is "the work already happened, nothing more to do". Swap to `fail!("duplicate", code: :duplicate)` when callers need to know the request was actively rejected (e.g. to surface a 409 instead of a 2xx).

!!! tip "Crash safety"

    The `rescue StandardError → del` branch releases the lock when the task crashes mid-flight. The `xx: true, ex: @ttl` final write only sets `done` when the key still exists, so a parallel TTL expiry can't accidentally re-create the key.
