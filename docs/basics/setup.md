# Basics - Setup

A task represents a unit of work to execute. While `CMDx` offers a plethora
of features, a `call` method is the only thing required to execute a task.

```ruby
class ProcessOrderTask < CMDx::Task

  def call
    # Do work...
  end

  private

  # Business logic...

end
```

> [!TIP]
> While complexity designed into a task is up to the engineer, it's
> suggested that tasks be small and composed into higher level tasks.

## Generator

Run `rails g cmdx:task [NAME]` to create a task template file under `app/cmds`.
Tasks will inherit from `ApplicationTask` if available or fall back to `CMDx::Task`.

---

- **Prev:** [Configuration](https://github.com/drexed/cmdx/blob/main/docs/configuration.md)
- **Next:** [Basics - Call](https://github.com/drexed/cmdx/blob/main/docs/basics/call.md)
