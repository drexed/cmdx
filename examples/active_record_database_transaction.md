# Active Record Database Transaction

Wrap a task's entire lifecycle in a database transaction so multi-step writes roll back together when something raises.

## Setup

```ruby
# app/middlewares/cmdx_database_transaction_middleware.rb
class CmdxDatabaseTransactionMiddleware
  def call(_task)
    ActiveRecord::Base.transaction(requires_new: true) { yield }
  end
end
```

## Usage

```ruby
class TransferFunds < CMDx::Task
  register :middleware, CmdxDatabaseTransactionMiddleware.new

  def work
    # ...
  end
end
```

## Notes

!!! warning "Important"

    A task that halts with `fail!` returns a `Result` — it does **not** raise. The transaction only rolls back when an exception escapes the inner block. To force a rollback on logical failure, raise inside `rollback` (see [Rollback](../docs/v2-migration.md#rollback)) or call `execute!`, which re-raises as `CMDx::Fault`.
