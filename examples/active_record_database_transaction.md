# Active Record Query Tagging

Wrap task or workflow execution in a database transaction. This is essential for data integrity when multiple steps modify the database.

### Setup

```ruby
# lib/cmdx_database_transaction_middleware.rb
class CmdxDatabaseTransactionMiddleware
  def self.call(task, **options, &)
    ActiveRecord::Base.transaction(requires_new: true, &)
  end
end
```

### Usage

```ruby
class MyTask < CMDx::Task
  register :middleware, CmdxDatabaseTransactionMiddleware

  def work
    # Do work...
  end

end
```
