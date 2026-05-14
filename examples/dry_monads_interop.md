# dry-monads Interop

A codebase that already speaks [dry-monads](https://dry-rb.org/gems/dry-monads) gets railway-style composition between heterogeneous operations: a CMDx task, a plain `Result`-returning service, and a third-party SDK can all be sequenced in one `Do` block without a single `if result.success?`.

## Result → `Success` / `Failure`

```ruby
# lib/cmdx_monads.rb
# frozen_string_literal: true

require "dry/monads"

module CMDxMonads
  extend Dry::Monads[:result]

  def self.for(result)
    if result.success? || result.skipped?
      Success(result.context)
    else
      Failure(reason: result.reason, metadata: result.metadata, result: result)
    end
  end
end
```

## Composing in a `Do` block

```ruby
class CompletePurchase
  include Dry::Monads[:result]
  include Dry::Monads::Do.for(:call)

  def call(user:, product_id:)
    reserved = yield CMDxMonads.for(ReserveInventory.execute(product_id:))
    charged  = yield CMDxMonads.for(ChargeCard.execute(user:, amount: reserved.amount_cents))
    yield             CMDxMonads.for(SendReceipt.execute(user:, charge: charged.charge))

    Success(charged.charge)
  end
end

case CompletePurchase.new.call(user:, product_id: 42)
in Success(charge)
  render json: { charge_id: charge.id }
in Failure(reason:, metadata:)
  render json: { error: reason, code: metadata[:code] }, status: :unprocessable_entity
end
```

## Failure → `fail!`

The reverse direction lets a task adapt a third-party `Failure` into a halt without leaking dry-monads types out of the task boundary.

```ruby
class ChargeCard < CMDx::Task
  required :user
  required :amount_cents, coerce: :integer

  def work
    PaymentGateway
      .charge(user.stripe_id, amount_cents)        # => Success(charge) | Failure(error)
      .fmap { |charge| context.charge = charge }
      .or   { |error|  fail!(error.message, code: :gateway_error, retryable: error.retryable?) }
  end
end
```

## Notes

!!! tip "Use pattern matching first"

    `Result` already implements `deconstruct_keys`, so `case result in { status: "success", context: }` works out of the box. dry-monads only earns its weight when you need `bind`/`fmap` composition across operations that aren't tasks.
