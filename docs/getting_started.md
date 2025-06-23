# Getting Started

CMDx is a Ruby framework for building maintainable, observable business logic through composable command objects. Design robust workflows with automatic parameter validation, structured error handling, comprehensive logging, and intelligent execution flow control that scales from simple tasks to complex multi-step processes.

## Goals

- Provide easy branching, nesting, and composition of complex tasks
- Supply intent, severity, and reasoning to halting execution of tasks
- Demystify root causes of complex multi-level tasks with exhaustive tracing

## Installation

Add CMDx to your Gemfile:

```ruby
gem 'cmdx'
```

For Rails applications, generate the configuration:

```bash
rails generate cmdx:install
```

This creates `config/initializers/cmdx.rb` with default settings.

## Quick Setup

Create your first task:

```ruby
class ProcessOrderTask < CMDx::Task
  # Parameter validation
  required :order_id, type: :integer
  optional :notify_customer, type: :boolean, default: true

  def call
    # Load data into context
    context.order = Order.find(order_id)

    # Business logic with conditional outcomes
    if context.order.canceled?
      fail!(reason: "Order was canceled", canceled_at: context.order.canceled_at)
    elsif context.order.processing?
      skip!(reason: "Order is already processing", processor: context.order.processor_id)
    else
      # Main processing
      context.order.update!(status: 'processed', processed_at: Time.current)
      send_confirmation_email if notify_customer
    end
  end

  private

  def send_confirmation_email
    # Call other tasks or services
    EmailService.send_confirmation(context.order)
  end
end
```

## Execution

Execute tasks using class methods:

```ruby
# Basic execution - returns Result object
result = ProcessOrderTask.call(order_id: 123, notify_customer: true)

# Exception-based execution - raises on failure/skip
result = ProcessOrderTask.call!(order_id: 123)
```

## Result Handling

Check execution outcomes:

```ruby
result = ProcessOrderTask.call(order_id: 123)

if result.success?
  # Task completed successfully
  flash[:success] = "Order processed successfully!"
  redirect_to order_path(result.context.order)
elsif result.skipped?
  # Task was skipped with reason
  flash[:notice] = "Skipped: #{result.metadata[:reason]}"
  redirect_to order_path(result.context.order)
elsif result.failed?
  # Task failed with error details
  flash[:error] = "Failed: #{result.metadata[:reason]}"
  render :edit
end

# Access execution metadata
puts "Runtime: #{result.runtime} seconds"
puts "Task ID: #{result.id}"
```

## Exception Handling

Use `call!` for exception-based control flow:

```ruby
begin
  result = ProcessOrderTask.call!(order_id: 123)
  redirect_to order_path(result.context.order), notice: "Success!"
rescue CMDx::Skipped => e
  redirect_to orders_path, notice: e.result.metadata[:reason]
rescue CMDx::Failed => e
  redirect_to order_path(123), alert: "Error: #{e.result.metadata[:reason]}"
end
```

## Building Workflows

Combine tasks using batches:

```ruby
class BatchProcessOrders < CMDx::Batch
  required :order_id, type: :integer

  # Sequential execution
  process ValidateOrderTask
  process ProcessPaymentTask
  process UpdateInventoryTask
  process SendConfirmationTask, if: proc { context.payment_successful? }

  # Hooks for workflow management
  before_execution :setup_workflow
  on_failed :handle_failure

  private

  def setup_workflow
    context.started_at = Time.current
  end

  def handle_failure
    NotificationService.alert_failure(context.order_id, result.metadata[:reason])
  end
end

# Execute the workflow
result = BatchProcessOrders.call(order_id: 123)
```

## Generators

Generate tasks and batches:

```bash
# Generate a task
rails generate cmdx:task ProcessOrder

# Generate a batch
rails generate cmdx:batch OrderProcessing
```

## Key Features

### Parameter Validation

```ruby
class ProcessUserTask < CMDx::Task
  required :email, type: :string, format: { with: /@/ }
  required :age, type: :integer, numeric: { min: 18 }

  # Nested parameters
  optional :address do
    required :street, :city, type: :string
    optional :apartment, type: :string
  end

  def call
    # Parameters automatically validated and accessible
    context.user = User.create!(email: email, age: age)
  end
end
```

### Lifecycle Hooks

```ruby
class ProcessTrackedTask < CMDx::Task
  before_execution :start_tracking
  after_execution :stop_tracking
  on_success :celebrate
  on_failed :alert_team, if: :critical?

  def call
    # Main logic
  end

  private

  def start_tracking
    context.start_time = Time.current
  end

  def critical?
    result.metadata[:severity] == "high"
  end
end
```

### Configuration

```ruby
class ProcessConfiguredTask < CMDx::Task
  task_settings!(
    task_timeout: 60,
    tags: ["critical", "payment"],
    logger: Rails.logger
  )

  def call
    logger.info "Processing payment", order_id: context.order_id
    # Business logic
  end
end
```

## Testing

Test tasks with RSpec:

```ruby
RSpec.describe ProcessOrderTask do
  it "processes valid orders" do
    order = create(:order, :pending)

    result = ProcessOrderTask.call(order_id: order.id)

    expect(result).to be_success
    expect(result.context.order.status).to eq('processed')
  end

  it "skips already processing orders" do
    order = create(:order, :processing)

    result = ProcessOrderTask.call(order_id: order.id)

    expect(result).to be_skipped
    expect(result.metadata[:reason]).to include("processing")
  end
end
```

---

- **Prev:** [Example](https://github.com/drexed/cmdx/blob/main/docs/example.md)
- **Next:** [Configuration](https://github.com/drexed/cmdx/blob/main/docs/configuration.md)
