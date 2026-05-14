# Pundit Authorization

A task that mutates data is a sensitive operation regardless of how it's invoked — controller, job, console. Centralizing the authorization decision in a [Pundit](https://github.com/varvet/pundit) policy keeps that decision unit-testable and reusable across every entry point.

## Authorization middleware

A middleware can halt the task directly via `task.fail!` — Runtime catches the thrown signal and produces a failed result without ever entering `work`.

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
      task.fail!("not authorized", code: :forbidden)
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

!!! note "Halt before yielding"

    Runtime wraps the middleware chain in `catch(Signal::TAG)`, so middlewares may halt with `success!` / `skip!` / `fail!` / `throw!`. Throw **before** calling `yield` (or `next_link.call`); a signal thrown after the lifecycle has already finalized is silently dropped — the lifecycle's outcome wins.
