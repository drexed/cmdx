# Pundit Authorization

A task that mutates data is a sensitive operation regardless of how it's invoked — controller, job, console. Centralizing the authorization decision in a [Pundit](https://github.com/varvet/pundit) policy keeps that decision unit-testable and reusable across every entry point.

## Authorization middleware

A middleware can't throw `fail!` directly (signals only originate inside `work`), but recording a policy denial as an error and yielding lets `signal_errors!` halt the task as failed during input resolution.

```ruby
# app/middlewares/cmdx_pundit_middleware.rb
# frozen_string_literal: true

class CmdxPunditMiddleware
  def initialize(action: :execute?, policy: nil)
    @action = action
    @policy = policy
  end

  def call(task)
    user   = task.context[:current_user]
    policy = (@policy || task.class).then { |klass| Pundit.policy!(user, klass) }

    unless policy.public_send(@action)
      task.errors.add(:base, "not authorized")
      task.metadata[:code] = :forbidden
    end

    yield
  end
end
```

```ruby
# app/tasks/application_task.rb
# frozen_string_literal: true

class ApplicationTask < CMDx::Task
  required :current_user
end
```

## Per-task policy

The policy class mirrors the task — Pundit's `policy!` resolves `CreateInvoice` to `CreateInvoicePolicy` automatically.

```ruby
class CreateInvoice < ApplicationTask
  register :middleware, CmdxPunditMiddleware.new(action: :create?)

  required :customer_id, coerce: :integer
  required :amount_cents, coerce: :integer

  def work
    context.invoice = Invoice.create!(customer_id:, amount_cents:)
  end
end
```

```ruby
# app/policies/create_invoice_policy.rb
# frozen_string_literal: true

class CreateInvoicePolicy < ApplicationPolicy
  def create?
    user.admin? || user.billing_manager?
  end
end
```

## Reacting to denials

Denials look like any other failed result, so callers branch on `metadata[:code]` instead of catching a special exception:

```ruby
result = CreateInvoice.execute(current_user: current_user, customer_id: 42, amount_cents: 9_900)

case result
in { status: "failed", metadata: { code: :forbidden } }
  redirect_to dashboard_path, alert: result.reason
in { status: "failed" }
  render :new, status: :unprocessable_entity
in { status: "success" }
  redirect_to result.context.invoice
end
```

## Notes

!!! tip "Inheritance opt-out"

    Registering the middleware on `ApplicationTask` covers every subclass automatically. Tasks that shouldn't be authorized (e.g. an internal background sweeper) drop it locally with `deregister :middleware, CmdxPunditMiddleware`.

!!! warning "Middlewares cannot throw signals"

    Calling `task.send(:fail!)` from a middleware throws past the lifecycle's `catch(Signal::TAG)` and surfaces as `UncaughtThrowError`. The `errors.add + yield` pattern is the signal-safe equivalent — `signal_errors!` picks the error up at input resolution and halts with a failed result whose `reason` carries the message.
