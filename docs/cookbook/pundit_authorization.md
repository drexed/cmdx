# Pundit Authorization

A task that changes data is sensitive no matter who calls it — a controller, a job, or a console session.

Centralize the “may this user run this?” check in a [Pundit](https://github.com/varvet/pundit) policy. Write the rule once; every entry point gets the same behavior and the same tests.

## Setup

Middleware loads the policy and halts with `task.fail!` when the action is denied. Runtime never enters `work`.

```ruby
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
class ApplicationTask < CMDx::Task
  required :current_user
end
```

## Usage

Register middleware on the task. Pundit resolves `CreateInvoice` → `CreateInvoicePolicy` by convention.

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
class CreateInvoicePolicy < ApplicationPolicy
  def create?
    user.admin? || user.billing_manager?
  end
end
```

## What to expect

Denials look like any other failed `Result`. Branch on `metadata[:code]` instead of rescuing a special exception:

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

### Inheritance opt-out

Register on `ApplicationTask` to cover every subclass. Internal sweepers that should not authorize can `deregister :middleware, CmdxPunditMiddleware` on that class alone.

### Halt before yielding

Throw `success!`, `skip!`, `fail!`, or `throw!` **before** `yield`. Signals thrown after the lifecycle finalizes are dropped — the lifecycle's outcome wins.
