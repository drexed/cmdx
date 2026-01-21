# ActiveSupport::Notifications Instrumentation

This example demonstrates how to wrap CMDx tasks with `ActiveSupport::Notifications` to instrument execution time and other metrics.

## Middleware

Create a middleware that wraps the task execution in an instrumentation block.

```ruby
# app/middlewares/active_support_instrumentation.rb
class CmdxActiveSupportInstrumentation
  def call(task, _options, &)
    ActiveSupport::Notifications.instrument(
      "execute.cmdx",
      task: task.class.name,
      task_id: task.id,
      context: task.context.to_h,
      &
    )
  end
end
```

## Usage

Register the middleware in your tasks or base task class.

```ruby
# app/tasks/users/create.rb
class Users::Create < CMDx::Task
  register :middleware, CmdxActiveSupportInstrumentation

  required :email

  def work
    # ... logic ...
  end
end
```

## Subscriber

Subscribe to the event to log or process the metrics.

```ruby
# config/initializers/cmdx_instrumentation.rb
ActiveSupport::Notifications.subscribe("execute.cmdx") do |name, start, finish, id, payload|
  duration = (finish - start) * 1000
  Rails.logger.info "Task #{payload[:task]} (ID: #{payload[:task_id]}) took #{duration.round(2)}ms"
end
```

## Result

When `Users::Create.execute` is called, it will trigger the notification:

```
Task Users::Create (ID: 018c2b95-...) took 45.21ms
```
