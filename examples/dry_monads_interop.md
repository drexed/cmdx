# dry-monads Interop

Convert CMDx `Result`s into [dry-monads](https://dry-rb.org/gems/dry-monads) values so tasks can participate in `Do` blocks or be chained with `bind` / `fmap`.

## Result → `Success` / `Failure`

```ruby
# lib/cmdx_monads.rb
require "dry/monads"

module CMDxMonads
  include Dry::Monads[:result]

  def self.for(result)
    if result.success? || result.skipped?
      Success(result.context)
    else
      Failure(reason: result.reason, metadata: result.metadata, result: result)
    end
  end
end
```

## Using `Do` Notation

```ruby
class PurchaseFlow
  include Dry::Monads[:result]
  include Dry::Monads::Do.for(:call)

  def call(user:, product_id:)
    reserved = yield CMDxMonads.for(ReserveInventory.execute(product_id:))
    charged  = yield CMDxMonads.for(ChargeCard.execute(user:, amount: reserved.amount))
    yield             CMDxMonads.for(SendReceipt.execute(user:, charge: charged.charge))

    Success(charged.charge)
  end
end

case PurchaseFlow.new.call(user:, product_id: 42)
in Success(charge)
  render json: { charge_id: charge.id }
in Failure(reason:, metadata:, result:)
  render json: { error: reason, code: metadata[:code] }, status: :unprocessable_entity
end
```

## Failure → `fail!`

The reverse direction: a task that receives a `Failure` from a dry-monads function halts cleanly.

```ruby
class ChargeCard < CMDx::Task
  required :user, :amount

  def work
    payment_gateway.charge(amount).to_result # => Success | Failure
      .fmap  { |charge| context.charge = charge }
      .or    { |err|    fail!(err.message, code: :gateway_error) }
  end
end
```

## Notes

!!! tip

    Use `result.deconstruct_keys` for native pattern matching instead of dry-monads when your only goal is destructuring — no gem required. dry-monads shines when you want railway-style composition across heterogeneous operations.
