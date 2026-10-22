# Active Record Database Transaction

Some tasks touch more than one row. Transfer money, create a parent and children, update a counter and a log table — you want **all** of those writes to land together.

Wrap the task lifecycle in an Active Record transaction. If the task halts with a logical failure (`fail!`), add a `rollback` hook so the database changes unwind too.

## Setup

Middleware opens a transaction around the rest of the chain. `requires_new: true` uses a savepoint for nested tasks (handy when a child fails but the parent can recover).

```ruby
class CmdxDatabaseTransactionMiddleware
  def initialize(requires_new: true)
    @requires_new = requires_new
  end

  def call(_task)
    ActiveRecord::Base.transaction(requires_new: @requires_new) { yield }
  end
end
```

`fail!` returns a failed `Result` — it does **not** raise. Without `rollback`, every write before the halt is already committed.

```ruby
class ApplicationTask < CMDx::Task
  register :middleware, CmdxDatabaseTransactionMiddleware.new

  def rollback
    raise ActiveRecord::Rollback
  end
end
```

## Usage

```ruby
class TransferFunds < ApplicationTask
  required :from_account_id, :to_account_id, coerce: :integer
  required :amount_cents,    coerce: :integer, validate: { numericality: { greater_than: 0 } }

  def work
    from = Account.lock.find(from_account_id)
    to   = Account.lock.find(to_account_id)

    fail!("insufficient funds", code: :insufficient_funds) if from.balance_cents < amount_cents

    from.update!(balance_cents: from.balance_cents - amount_cents)
    to.update!(balance_cents: to.balance_cents + amount_cents)
    LedgerEntry.create!(from:, to:, amount_cents:)
  end
end
```

## Notes

### `fail!` does not raise

A halted task unwinds normally and the outer transaction would commit unless `rollback` raises `ActiveRecord::Rollback`. Active Record swallows `Rollback` quietly; your `Result` still reports `failed?`.

### Nested tasks

With `requires_new: true`, a child task's failure rolls back only its savepoint. Set `requires_new: false` when nested tasks must share the parent's single transaction boundary.
