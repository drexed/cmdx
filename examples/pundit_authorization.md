# Pundit Authorization

Authorize CMDx tasks with [Pundit](https://github.com/varvet/pundit) policies by failing fast when the current user isn't permitted to execute the task.

## Authorization Middleware

A single middleware checks a policy for every task that opts in.

```ruby
# app/middlewares/cmdx_pundit_middleware.rb
class CmdxPunditMiddleware
  def initialize(action: :execute?)
    @action = action
  end

  def call(task)
    policy = Pundit.policy!(task.context.current_user, task.class)
    task.send(:fail!, "not authorized", code: :forbidden) unless policy.public_send(@action)

    yield
  end
end
```

```ruby
class ApplicationTask < CMDx::Task
  required :current_user
end

class CreateInvoice < ApplicationTask
  register :middleware, CmdxPunditMiddleware.new(action: :create?)

  required :customer_id, coerce: :integer

  def work
    context.invoice = Invoice.create!(...)
  end
end
```

## Per-task Policy Class

Define a Pundit policy that mirrors the task, exactly like a model policy:

```ruby
# app/policies/create_invoice_policy.rb
class CreateInvoicePolicy < ApplicationPolicy
  def create?
    user.admin? || user.billing_manager?
  end
end
```

Pundit's `policy!` resolves `CreateInvoicePolicy` from `CreateInvoice` automatically.

## Reacting to Denials

Because the middleware halts with `fail!`, the `Result` is already a standard failure — no special casing in callers:

```ruby
result = CreateInvoice.execute(current_user:, customer_id: 42)

if result.failed? && result.metadata[:code] == :forbidden
  redirect_to dashboard_path, alert: result.reason
end
```

## Notes

!!! tip

    Put the middleware on `ApplicationTask` so every subclass inherits it automatically. Tasks that shouldn't be authorized can `deregister :middleware, CmdxPunditMiddleware` in their declaration.
