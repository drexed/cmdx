# Basics - Setup

A task represents a unit of work to execute. Tasks are the core building blocks
of CMDx, encapsulating business logic within a structured, reusable object. While
CMDx offers extensive features like parameter validation, hooks, and state tracking,
only a `call` method is required to create a functional task.

## Basic Task Structure

```ruby
class ProcessOrderTask < CMDx::Task

  def call
    # Your business logic here
    context.order = Order.find(context.order_id)
    context.order.process!
  end

  private

  # Support methods and business logic

end
```

## Task Execution

Tasks are executed using class-level call methods, not by instantiating objects directly:

```ruby
# Execute a task
result = ProcessOrderTask.call(order_id: 123)

# Access the result
result.success?     #=> true
result.context.order #=> <Order id: 123>
```

## Inheritance and Application Tasks

In Rails applications, tasks typically inherit from an `ApplicationTask` base class:

```ruby
# app/tasks/application_task.rb
class ApplicationTask < CMDx::Task
  # Shared configuration and functionality
end

# app/tasks/process_order_task.rb
class ProcessOrderTask < ApplicationTask
  def call
    # Implementation
  end
end
```

## Available Features

Tasks can leverage many built-in features:

- **Parameter validation** with required/optional parameters
- **Type coercion** for automatic data conversion
- **Hooks** for lifecycle event handling
- **State tracking** with success/failure/skip states
- **Context storage** for data sharing between tasks
- **Error handling** with custom exceptions
- **Logging** with structured output

## Generator

Rails applications can use the built-in generator to create task templates:

```bash
rails g cmdx:task ProcessOrder
```

This creates `app/tasks/process_order_task.rb` with:
- Proper inheritance from `ApplicationTask` (if available) or `CMDx::Task`
- Basic structure with parameter definitions
- Template implementation

## Task Lifecycle

Every task follows a predictable lifecycle:

1. **Instantiation** - Task object created with context
2. **Validation** - Parameters validated against definitions
3. **Execution** - The `call` method runs business logic
4. **Completion** - Result finalized with state and status
5. **Freezing** - Task becomes immutable after execution

## Best Practices

- **Design tasks to be small and focused** on a single responsibility
- **Compose complex workflows** by calling multiple tasks rather than building monolithic task objects
- **Use consistent naming conventions** following `Verb + Noun + Task` pattern
- **Leverage inheritance** for shared functionality across related tasks

> [!IMPORTANT]
> Tasks are single-use objects. Once executed, they are frozen and cannot
> be called again. Create a new task instance for each execution.

---

- **Prev:** [Configuration](https://github.com/drexed/cmdx/blob/main/docs/configuration.md)
- **Next:** [Basics - Call](https://github.com/drexed/cmdx/blob/main/docs/basics/call.md)
