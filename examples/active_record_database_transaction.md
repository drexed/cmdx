# Active Record Database Transaction

A task that performs multiple writes — credit one account, debit another, write a ledger row — must commit atomically. Wrapping the lifecycle in a transaction guarantees either every write lands or none do.

## Setup

```ruby
# app/middlewares/cmdx_database_transaction_middleware.rb
# frozen_string_literal: true

class CmdxDatabaseTransactionMiddleware
  def initialize(requires_new: true)
    @requires_new = requires_new
  end

  def call(_task)
    ActiveRecord::Base.transaction(requires_new: @requires_new) { yield }
  end
end
```

A `rollback` hook converts a logical halt into a transaction rollback. Without it, `fail!` returns a failed `Result` but every write up to that point is already committed.

```ruby
# app/tasks/application_task.rb
# frozen_string_literal: true

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

!!! warning "fail! does not raise"

    A task that halts via `fail!` returns a `Result` — execution unwinds normally and the transaction commits. `rollback` raising `ActiveRecord::Rollback` is what discards the writes. `Rollback` is silently swallowed by `transaction`, so the surrounding `Result` still reports `failed?`.

!!! tip "Nested tasks"

    `requires_new: true` opens a SAVEPOINT for nested invocations, so a child task's failure rolls back only its own writes and leaves the parent free to recover. Switch to `requires_new: false` when nested tasks must share the parent's transaction boundary.
