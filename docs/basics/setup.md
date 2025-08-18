# Basics - Setup

A task represents a unit of work to execute. Tasks are the core building blocks of CMDx, encapsulating business logic within a structured, reusable object. While CMDx offers extensive features like parameter validation, callbacks, and state tracking, only a `call` method is required to create a functional task.

## Table of Contents

- [Structure](#structure)
- [Inheritance](#inheritance)
- [Lifecycle](#lifecycle)
- [Errors](#errors)

## Structure

Tasks are Ruby classes that inherit from `CMDx::Task` and only require a `work` method
- all other features are optional and can be added as needed.

```ruby
class ProcessUserOrder < CMDx::Task
  def work
    # Your logic here...
  end
end
```

## Inheritance

Create an `ApplicationTask` base class to share common configuration
and functionality across all your tasks. Mechanisms like middlewares,
validators, and attributes are inherited from the parent class.

```ruby
class ApplicationTask < CMDx::Task
  register :middleware, AuthenticateUserMiddleware

  before_execution :set_correlation_id

  attribute :request_id, type: :string

  private

  def set_correlation_id
    context.correlation_id ||= SecureRandom.uuid
  end
end
```

## Lifecycle

Understanding the task lifecycle is crucial for proper error handling and debugging.
Tasks follow a predictable execution pattern with specific states and status transitions.

### Lifecycle Stages

| Stage | Description | State | Possible Statuses |
|-------|-------------|--------|-------------------|
| **Instantiation** | Task object created with context | `initialized` | `success` |
| **Validation** | Parameters validated against definitions | `executing` | `success`, `failed` |
| **Execution** | The `call` method runs business logic | `executing` | `success`, `failed`, `skipped` |
| **Post-execution** | After callbacks run | `executing` | `success`, `failed`, `skipped` |
| **Completion** | Result finalized with final state | `executed` | `success`, `failed`, `skipped` |
| **Freezing** | Task becomes immutable | `executed` | `success`, `failed`, `skipped` |

> [!WARNING]
> Tasks are single-use objects. Once executed, they are frozen and cannot be called again.
> Attempting to call a frozen task will raise an error.

### Lifecycle Example

```ruby
class ProcessTask < CMDx::Task
  required :data, type: :string

  before_execution :log_start

  def work
    # Your logic here...
  end

  private

  def log_start
    puts "Task starting with data: #{context.data}"
  end
end

# Execution
result = ProcessTask.execute(data: "hello")

result.state  #=> "executed"
result.status #=> "success"
```

```ruby
task = ProcessOrderTask.new(order_id: 123)
result1 = task.execute # ✓ Works
result2 = task.execute # ✗ Raises FrozenError

# Create new instances for each execution
result1 = ProcessOrderTask.execute(order_id: 123)
result2 = ProcessOrderTask.execute(order_id: 456) # ✓ Works
```

## Errors

CMDx provides comprehensive error handling with detailed metadata about skipped and failed tasks,
including parameter validation errors, execution exceptions, and halt conditions.

### Parameter Validation Errors

```ruby
class ProcessOrderTask < CMDx::Task
  required :order_id, type: :integer
  optional :amount, type: :float

  def work
    # Your logic here...
  end
end

# Invalid parameters
result = ProcessOrderTask.execute(
  order_id: "not-a-number",
  amount: "invalid"
)

result.state    #=> "interrupted"
result.status   #=> "failed"
result.reason   #=> "order_id could not coerce into an integer. amount could not coerce into a float."
result.metadata #=> {
                #     messages: {
                #       order_id: ["could not coerce into an integer"],
                #       amount: ["could not coerce into a float"]
                #     }
                #   }
```

### Runtime Exceptions

```ruby
class ProcessOrderTask < CMDx::Task
  required :order_id, type: :integer

  def work
    order = Order.find(context.order_id)
    order.process!
  end
end

# Order not found
result = ProcessOrderTask.execute(order_id: 99999)

result.state  #=> "interrupted"
result.status #=> "failed"
result.reason #=> "ActiveRecord::RecordNotFound: Couldn't find Order..."
```

---

- **Prev:** [Getting Started](../getting_started.md)
- **Next:** [Basics - Execution](execution.md)
