---
date: 2026-04-08
authors:
  - drexed
categories:
  - Tutorials
slug: returns-and-contracts
---

# Returns and Contracts: Making Your Tasks Predictable

*Targets CMDx v1.20.*

I used to have a recurring nightmare. Not the falling kind—the kind where I'm staring at a service object and trying to figure out what it puts into the context. The `work` method sets `context.user` on line 12, `context.token` on line 28, but only if the conditional on line 15 passes. Oh, and there's a `context.session_id` that gets set inside a private method three screens down.

Every consumer of that task is making an implicit assumption about what the context will contain after execution. When those assumptions break, the error shows up somewhere else entirely—a `NoMethodError` in a downstream task, a nil where a mailer expected a user object.

That's why I built `returns` into CMDx. It makes the output contract explicit, enforced, and impossible to forget.

<!-- more -->

## The Problem with Implicit Outputs

Consider a typical Ruby task without declared returns:

```ruby
class AuthenticateUser < CMDx::Task
  required :email, :password

  def work
    user = User.find_by(email: email)

    if user&.authenticate(password)
      context.user = user
      context.token = JwtService.encode(user_id: user.id)
      context.authenticated_at = Time.current
    else
      fail!("Invalid credentials")
    end
  end
end
```

This works fine—until someone refactors the JWT logic and forgets to set `context.token`. The task succeeds (the user authenticated), but the downstream code that reads `result.context.token` gets `nil`. You find out in production when the API returns a 500 because the response serializer can't handle a nil token.

## Declaring Returns

The fix is one line:

```ruby
class AuthenticateUser < CMDx::Task
  required :email, :password

  returns :user, :token

  def work
    user = User.find_by(email: email)

    if user&.authenticate(password)
      context.user = user
      context.token = JwtService.encode(user_id: user.id)
      context.authenticated_at = Time.current
    else
      fail!("Invalid credentials")
    end
  end
end
```

`returns :user, :token` tells CMDx: "After `work` completes successfully, these keys must exist in the context." If either is missing, the task automatically fails with a clear error:

```ruby
# Suppose we forgot to set context.token
result = AuthenticateUser.execute(email: "ada@example.com", password: "secret")

result.failed?   #=> true
result.reason    #=> "Invalid"
result.metadata
#=> {
#     errors: {
#       full_message: "token must be set in the context",
#       messages: { token: ["must be set in the context"] }
#     }
#   }
```

The failure happens immediately, at the source, with a message that tells you exactly what's missing. No downstream nil errors, no production mystery.

## The Full Input/Output Contract

When you combine `required`, `optional`, and `returns`, you get a complete contract—the task's interface is fully documented in three lines:

```ruby
class TransferFunds < CMDx::Task
  # Inputs
  required :from_account_id, type: :integer
  required :to_account_id, type: :integer
  required :amount, type: :big_decimal, numeric: { min: 0.01 }
  optional :memo, length: { max: 255 }

  # Outputs
  returns :transaction, :new_balance

  def work
    from = Account.find(from_account_id)
    to = Account.find(to_account_id)

    if from.balance < amount
      fail!("Insufficient funds", code: :insufficient_balance,
        available: from.balance, requested: amount)
    end

    context.transaction = Ledger.transfer!(from: from, to: to, amount: amount, memo: memo)
    context.new_balance = from.reload.balance
  end
end
```

Anyone reading this task—a teammate, a future you, an LLM—knows exactly:

- **What it needs**: `from_account_id`, `to_account_id`, `amount`, and optionally `memo`
- **What types it expects**: integers, big decimal, string
- **What it guarantees**: a `transaction` and `new_balance` in the context on success
- **What can go wrong**: insufficient funds, with structured metadata

This is a contract in the truest sense. The caller knows what to provide. The consumer knows what to expect. The task enforces both sides.

## Validation Timing

Returns are validated *after* `work` completes and *only* when the task is still successful. This is important—if your task calls `fail!` or `skip!`, return validation doesn't run:

```ruby
class FindUser < CMDx::Task
  required :email

  returns :user

  def work
    user = User.find_by(email: email)

    if user.nil?
      fail!("User not found")  # Returns validation skipped
    end

    context.user = user
  end
end
```

This makes sense—if the task already failed, there's no point checking whether it set its outputs. The failure reason is already captured.

The flow looks like this:

1. `work` runs
2. If still successful → validate returns
3. If any return is missing → fail with error
4. If already failed/skipped → skip return validation

## Inheritance and Removals

Returns are inherited from parent classes. This is powerful for establishing organization-wide contracts:

```ruby
class ApplicationTask < CMDx::Task
  returns :audit_log
end
```

Now every task in your app must set `context.audit_log`. But what about tasks that legitimately don't produce an audit log? Use `remove_returns`:

```ruby
class HealthCheck < ApplicationTask
  remove_returns :audit_log

  def work
    context.status = :ok
    context.timestamp = Time.current
  end
end
```

This is cleaner than wrapping every task's `work` in "don't forget the audit log" logic. The base class establishes the default, and specific tasks opt out explicitly.

### Building Layered Contracts

In larger applications, I use this layering to build domain-specific contracts:

```ruby
class ApplicationTask < CMDx::Task
  returns :audit_log
end

class Billing::BaseTask < ApplicationTask
  returns :billing_event
end

class Billing::ChargeCard < Billing::BaseTask
  required :amount_cents, type: :integer
  required :customer_id, presence: true

  returns :charge

  # Must set: audit_log (from ApplicationTask)
  #           billing_event (from Billing::BaseTask)
  #           charge (from this class)

  def work
    context.charge = PaymentGateway.charge(amount_cents, customer_id)
    context.billing_event = { type: :charge, amount: amount_cents, at: Time.current }
    context.audit_log = "Charged #{amount_cents} to #{customer_id}"
  end
end
```

The inheritance chain builds up the full list of required outputs. Forget any one of them and the task fails—even if the business logic completed successfully.

## Returns via Settings

You can also declare returns through the `settings` DSL, which is useful when you want to keep all configuration in one place:

```ruby
class GenerateReport < CMDx::Task
  settings(
    tags: ["reports"],
    returns: [:report, :download_url]
  )

  required :report_type, inclusion: { in: %w[daily weekly monthly] }

  def work
    context.report = ReportBuilder.build(report_type)
    context.download_url = StorageService.upload(context.report)
  end
end
```

Both approaches—`returns` class method and `settings(returns: [...])`—produce the same behavior. Use whichever reads better in context.

## Returns with Bang Execution

When using `execute!`, missing returns raise a `CMDx::FailFault` just like any other failure:

```ruby
begin
  result = AuthenticateUser.execute!(email: "ada@example.com", password: "secret")
  # If we get here, both :user and :token are guaranteed to exist
  session[:token] = result.context.token
rescue CMDx::FailFault => e
  if e.result.metadata.dig(:errors, :messages, :token)
    # Token wasn't set—this is a bug, not a user error
    ErrorTracker.report("AuthenticateUser missing return: token")
  end
  redirect_to login_path, alert: e.result.reason
end
```

This is a nice property—after `execute!` returns successfully, you *know* the context contains everything declared in `returns`. No nil checking needed.

## Testing Returns

Testing return enforcement is straightforward. Force the task to not set a return and verify it fails:

```ruby
RSpec.describe AuthenticateUser do
  it "fails when authentication returns nil user" do
    allow(User).to receive(:find_by).and_return(nil)

    result = AuthenticateUser.execute(email: "nobody@example.com", password: "wrong")

    expect(result).to be_failed
  end

  it "guarantees user and token on success" do
    user = create(:user, password: "secret123")

    result = AuthenticateUser.execute(email: user.email, password: "secret123")

    expect(result).to be_success
    expect(result.context.user).to eq(user)
    expect(result.context.token).to be_present
  end
end
```

The first test verifies that returns catch missing outputs. The second verifies the happy path sets everything. Together, they prove the contract is enforced.

## When to Use Returns

Not every task needs declared returns. Here's my rule of thumb:

**Use returns when:**

- The task produces data that downstream tasks or callers depend on
- Multiple places consume the task's output and expect specific keys
- The task is part of a workflow where context flows between steps
- You're building a public/shared task that other teams will use

**Skip returns when:**

- The task is a pure side effect (sending an email, logging an event)
- The task only modifies existing context values
- It's a leaf task in a workflow with no downstream consumers

```ruby
# Returns make sense — consumers depend on these outputs
class CreateOrder < CMDx::Task
  returns :order, :order_number
  # ...
end

# Returns don't add value — this is a pure side effect
class SendConfirmationEmail < CMDx::Task
  def work
    OrderMailer.confirmation(context.order).deliver_later
  end
end
```

## Key Takeaways

1. **Returns make implicit contracts explicit.** No more guessing what a task puts into context.

2. **Failures happen at the source.** A missing return fails the task immediately, not three steps later as a nil error.

3. **Combined with attributes, returns form a complete contract.** Inputs are validated before `work`, outputs are validated after.

4. **Inheritance builds layered contracts.** Base classes establish defaults, subclasses add specifics, `remove_returns` opts out.

5. **Returns only validate on success.** Failed or skipped tasks skip return validation entirely.

6. **Not every task needs returns.** Use them for data producers, skip them for pure side effects.

The best code is code that can't be misused. Returns won't make your task faster or more elegant, but they'll make it impossible to silently produce incomplete results. And in production, that's worth more than elegance.

Happy coding!

## References

- [Returns](https://drexed.github.io/cmdx/returns/)
- [Attributes](https://drexed.github.io/cmdx/attributes/definitions/)
- [Testing](https://drexed.github.io/cmdx/testing/)
