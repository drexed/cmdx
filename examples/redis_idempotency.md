# Redis Idempotency

Ensure tasks are executed exactly once using Redis to store execution state. This is critical for non-idempotent operations like charging a credit card or sending an email.

### Setup

```ruby
# lib/cmdx_redis_idempotency_middleware.rb
class CmdxRedisIdempotencyMiddleware
  def self.call(task, **options, &block)
    key = generate_key(task, options[:key])
    ttl = options[:ttl] || 5.minutes.to_i

    # Attempt to lock the key
    if Redis.current.set(key, "processing", nx: true, ex: ttl)
      begin
        block.call.tap |result|
          Redis.current.set(key, result.status, xx: true, ex: ttl)
        end
      rescue => e
        Redis.current.del(key)
        raise(e)
      end
    else
      # Key exists, handle duplicate
      status = Redis.current.get(key)

      if status == "processing"
        task.result.tap { |r| r.skip!("Duplicate request: currently processing", halt: true) }
      else
        task.result.tap { |r| r.skip!("Duplicate request: already processed (#{status})", halt: true) }
      end
    end
  end

  def self.generate_key(task, key_gen)
    id = if key_gen.respond_to?(:call)
           key_gen.call(task)
         elsif key_gen.is_a?(Symbol)
           task.send(key_gen)
         else
           task.context[:idempotency_key]
         end

    "cmdx:idempotency:#{task.class.name}:#{id}"
  end
end
```

### Usage

```ruby
class ChargeCustomer < CMDx::Task
  # Use context[:payment_id] as the unique key
  register :middleware, CmdxIdempotencyMiddleware,
    key: ->(t) { t.context[:payment_id] }

  def work
    # Charge logic...
  end
end

# First run: Executes
ChargeCustomer.call(payment_id: "123")
# => Success

# Second run: Skips
ChargeCustomer.call(payment_id: "123")
# => Skipped (reason: "Duplicate request: already processed (success)")
```

