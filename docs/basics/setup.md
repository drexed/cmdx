# Basics - Setup

A task represents a unit of work to execute. Tasks are the core building blocks of CMDx, encapsulating business logic within a structured, reusable object. While CMDx offers extensive features like parameter validation, callbacks, and state tracking, only a `call` method is required to create a functional task.

## Table of Contents

- [TLDR](#tldr)
- [Basic Task Structure](#basic-task-structure)
- [Task Execution](#task-execution)
- [Inheritance and Application Tasks](#inheritance-and-application-tasks)
- [Generator](#generator)
- [Task Lifecycle](#task-lifecycle)
- [Error Handling](#error-handling)

## TLDR

```ruby
# Minimal task - only call method required
class ProcessOrderTask < CMDx::Task
  def call
    context.result = "Order processed"
  end
end

# Execute and access results
result = ProcessOrderTask.call(order_id: 123)
result.success?        # → true
result.context.result  # → "Order processed"

# With parameters and validation
class UpdateUserTask < CMDx::Task
  required :user_id, type: :integer
  required :email, type: :string

  def call
    user = User.find(context.user_id)
    user.update!(email: context.email)
  end
end

# Generator for quick scaffolding
rails g cmdx:task ProcessPayment  # Creates structured template
```

## Basic Task Structure

> [!NOTE]
> Tasks are Ruby classes that inherit from `CMDx::Task`. Only the `call` method is required - all other features are optional and can be added as needed.

### Minimal Task

```ruby
class ProcessUserOrderTask < CMDx::Task
  def call
    # Your business logic here
    context.order = Order.find(context.order_id)
    context.order.process!
  end
end
```

### Complete Task Structure

```ruby
class ProcessPaymentTask < CMDx::Task
  # Parameter definitions (optional)
  required :amount, type: :float
  required :user_id, type: :integer
  optional :currency, type: :string, default: "USD"

  # Callbacks (optional)
  before_call :validate_user
  after_call :send_notification

  def call
    # Core business logic
    user = User.find(context.user_id)
    payment = Payment.create!(
      user: user,
      amount: context.amount,
      currency: context.currency
    )

    context.payment = payment
    context.success_message = "Payment processed successfully"
  end

  private

  def validate_user
    # Validation logic
  end

  def send_notification
    # Notification logic
  end
end
```

## Task Execution

> [!IMPORTANT]
> Tasks return a `CMDx::Result` object that contains execution state, context data, and metadata. Always check the result status before accessing context data.

### Basic Execution

```ruby
# Execute a task
result = ProcessUserOrderTask.call(order_id: 123)

# Check execution status
result.success?      # → true/false
result.failed?       # → true/false

# Access context data
result.context.order # → <Order id: 123>

# Access execution metadata
result.status        # → :success, :failure, etc.
result.state         # → :executed, :skipped, etc.
result.runtime       # → 0.1234 (seconds)
```

### Handling Different Outcomes

```ruby
result = ProcessPaymentTask.call(
  amount: 99.99,
  user_id: 12345,
  currency: "EUR"
)

case result.status
when :success
  payment = result.context.payment
  puts result.context.success_message
when :failure
  puts "Payment failed: #{result.metadata[:reason]}"
when :halt
  puts "Payment halted: #{result.metadata[:reason]}"
end
```

## Inheritance and Application Tasks

> [!TIP]
> In Rails applications, create an `ApplicationTask` base class to share common configuration, middleware, and functionality across all your tasks.

### Application Base Class

```ruby
# app/tasks/application_task.rb
class ApplicationTask < CMDx::Task
  # Shared configuration
  use :middleware, AuthenticateUserMiddleware
  use :middleware, LogExecutionMiddleware

  # Common callbacks
  before_call :set_correlation_id
  after_call :cleanup_temp_data

  # Shared parameter definitions
  optional :current_user, type: :virtual
  optional :request_id, type: :string

  private

  def set_correlation_id
    context.correlation_id ||= SecureRandom.uuid
  end

  def cleanup_temp_data
    # Cleanup logic
  end
end
```

### Task Implementation

```ruby
# app/tasks/process_user_order_task.rb
class ProcessUserOrderTask < ApplicationTask
  required :order_id, type: :integer
  required :payment_method, type: :string

  def call
    # Inherits all ApplicationTask functionality
    order = Order.find(context.order_id)

    # Business logic specific to this task
    process_order(order)
    charge_payment(order, context.payment_method)

    context.order = order
  end

  private

  def process_order(order)
    # Implementation
  end

  def charge_payment(order, method)
    # Implementation
  end
end
```

## Generator

> [!NOTE]
> Rails applications can use the built-in generator to create consistent task templates with proper structure and naming conventions.

### Basic Task Generation

```bash
# Generate a basic task
rails g cmdx:task ProcessUserOrder
```

This creates `app/tasks/process_user_order_task.rb`:

```ruby
class ProcessUserOrderTask < ApplicationTask
  # Define required parameters
  # required :param_name, type: :string

  # Define optional parameters
  # optional :param_name, type: :string, default: "default_value"

  def call
    # Implement your task logic here
    # Access parameters via context.param_name
  end

  private

  # Add private methods for supporting logic
end
```

### Advanced Generation Options

```bash
# Generate with workflow
rails g cmdx:workflow ProcessOrder

# Generate with specific namespace
rails g cmdx:task Billing::ProcessPayment
```

## Task Lifecycle

> [!IMPORTANT]
> Understanding the task lifecycle is crucial for proper error handling and debugging. Tasks follow a predictable execution pattern with specific states and status transitions.

### Lifecycle Stages

| Stage | Description | State | Possible Statuses |
|-------|-------------|--------|-------------------|
| **Instantiation** | Task object created with context | `:initialized` | `:pending` |
| **Pre-validation** | Before callbacks and middleware run | `:executing` | `:pending` |
| **Validation** | Parameters validated against definitions | `:executing` | `:pending`, `:failure` |
| **Execution** | The `call` method runs business logic | `:executing` | `:pending`, `:halt` |
| **Post-execution** | After callbacks run | `:executing` | `:success`, `:failure` |
| **Completion** | Result finalized with final state | `:executed` | `:success`, `:failure` |
| **Freezing** | Task becomes immutable | `:executed` | Final status |

### Lifecycle Example

```ruby
class ExampleTask < CMDx::Task
  required :data, type: :string

  before_call :log_start
  after_call :log_completion

  def call
    # Main logic
    context.processed_data = context.data.upcase
  end

  private

  def log_start
    puts "Task starting with data: #{context.data}"
  end

  def log_completion
    puts "Task completed: #{context.processed_data}"
  end
end

# Execution trace
result = ExampleTask.call(data: "hello")
# Output:
# Task starting with data: hello
# Task completed: HELLO

result.state   # → :executed
result.status  # → :success
```

> [!WARNING]
> Tasks are single-use objects. Once executed, they are frozen and cannot be called again. Attempting to call a frozen task will raise an error.

```ruby
task = ProcessOrderTask.new(order_id: 123)
result1 = task.call  # ✓ Works
result2 = task.call  # ✗ Raises FrozenError

# Create new instances for each execution
result1 = ProcessOrderTask.call(order_id: 123)
result2 = ProcessOrderTask.call(order_id: 456)  # ✓ Works
```

## Error Handling

> [!NOTE]
> CMDx provides comprehensive error handling with detailed metadata about failures, including parameter validation errors, execution exceptions, and halt conditions.

### Parameter Validation Errors

```ruby
class ProcessOrderTask < CMDx::Task
  required :order_id, type: :integer
  required :amount, type: :float

  def call
    # Task logic
  end
end

# Invalid parameters
result = ProcessOrderTask.call(
  order_id: "not-a-number",
  amount: "invalid"
)

result.failed?  # → true
result.status   # → :failure
result.metadata
# {
#   reason: "order_id could not coerce into an integer. amount could not coerce into a float.",
#   messages: {
#     order_id: ["could not coerce into an integer"],
#     amount: ["could not coerce into a float"]
#   }
# }
```

### Runtime Exceptions

```ruby
class ProcessOrderTask < CMDx::Task
  required :order_id, type: :integer

  def call
    order = Order.find(context.order_id)  # May raise ActiveRecord::RecordNotFound
    order.process!
  end
end

# Order not found
result = ProcessOrderTask.call(order_id: 99999)

result.failed?  # → true
result.status   # → :failure
result.metadata[:reason]  # → "ActiveRecord::RecordNotFound: Couldn't find Order..."
```

---

- **Prev:** [Configuration](../configuration.md)
- **Next:** [Basics - Call](call.md)
