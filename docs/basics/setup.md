# Basics - Setup

A task represents a unit of work to execute. Tasks are the core building blocks
of CMDx, encapsulating business logic within a structured, reusable object. While
CMDx offers extensive features like parameter validation, hooks, and state tracking,
only a `call` method is required to create a functional task.

## Table of Contents

- [Basic Task Structure](#basic-task-structure)
- [Task Execution](#task-execution)
- [Inheritance and Application Tasks](#inheritance-and-application-tasks)
- [Generator](#generator)
- [Task Lifecycle](#task-lifecycle)

## Basic Task Structure

```ruby
class ProcessUserOrderTask < CMDx::Task

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
result = ProcessUserOrderTask.call(order_id: 123)

# Access the result
result.success?      #=> true
result.context.order #=> <Order id: 123>
```

## Inheritance and Application Tasks

In Rails applications, tasks typically inherit from an `ApplicationTask` base class:

```ruby
# app/tasks/application_task.rb
class ApplicationTask < CMDx::Task
  # Shared configuration and functionality
end

# app/tasks/process_user_order_task.rb
class ProcessUserOrderTask < ApplicationTask
  def call
    # Implementation
  end
end
```

## Generator

Rails applications can use the built-in generator to create task templates:

```bash
rails g cmdx:task ProcessUserOrder
```

This creates `app/tasks/process_user_order_task.rb` with:
- Proper inheritance from `ApplicationTask` (if available) or `CMDx::Task`
- Basic structure with parameter definitions
- Template implementation

> [!TIP]
> Use the generator to maintain consistent task structure and naming conventions across your application.

## Task Lifecycle

Every task follows a predictable lifecycle:

1. **Instantiation** - Task object created with context
2. **Validation** - Parameters validated against definitions
3. **Execution** - The `call` method runs business logic
4. **Completion** - Result finalized with state and status
5. **Freezing** - Task becomes immutable after execution

> [!IMPORTANT]
> Tasks are single-use objects. Once executed, they are frozen and cannot
> be called again. Create a new task instance for each execution.

---

- **Prev:** [Configuration](https://github.com/drexed/cmdx/blob/main/docs/configuration.md)
- **Next:** [Basics - Call](https://github.com/drexed/cmdx/blob/main/docs/basics/call.md)
