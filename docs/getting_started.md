# Getting Started

CMDx is a Ruby framework for building maintainable, observable business logic through composable command objects. Design robust workflows with automatic parameter validation, structured error handling, comprehensive logging, and intelligent execution flow control that scales from simple tasks to complex multi-step processes.

## Table of Contents

- [TLDR](#tldr)
- [Installation](#installation)
- [Quick Setup](#quick-setup)
- [Execution](#execution)
- [Result Handling](#result-handling)
- [Exception Handling](#exception-handling)
- [Building Workflows](#building-workflows)
- [Code Generation](#code-generation)

## TLDR

```ruby
# Installation
gem 'cmdx'                    # Add to Gemfile
rails g cmdx:install          # Generate config

# Basic task
class ProcessOrderTask < CMDx::Task
  required :order_id, type: :integer
  optional :send_email, type: :boolean, default: true

  def call
    context.order = Order.find(order_id)
    fail!("Order canceled") if context.order.canceled?
    skip!("Already processed") if context.order.completed?

    context.order.update!(status: 'completed')
  end
end

# Execution
result = ProcessOrderTask.call(order_id: 123)     # Returns Result
result = ProcessOrderTask.call!(order_id: 123)    # Raises on failure

# Check outcomes
result.success? && result.context.order          # Access data
result.failed? && result.metadata[:reason]       # Error details
```

## Installation

Add CMDx to your Gemfile:

```ruby
gem 'cmdx'
```

For Rails applications, generate the configuration:

```bash
rails generate cmdx:install
```

> [!NOTE]
> This creates `config/initializers/cmdx.rb` with default settings for logging, error handling, and middleware configuration.

## Quick Setup

> [!TIP]
> Use **present tense verbs** for task names: `ProcessOrderTask`, `SendEmailTask`, `ValidatePaymentTask`

```ruby
class ProcessOrderTask < CMDx::Task
  required :order_id, type: :integer
  optional :send_email, type: :boolean, default: true

  def call
    context.order = Order.find(order_id)

    if context.order.canceled?
      fail!(reason: "Order canceled", canceled_at: context.order.canceled_at)
    elsif context.order.completed?
      skip!(reason: "Already processed")
    else
      context.order.update!(status: 'completed', completed_at: Time.now)
      EmailService.send_confirmation(context.order) if send_email
    end
  end
end
```

### Parameter Definition

Parameters provide automatic type coercion and validation:

```ruby
class CreateUserTask < CMDx::Task
  required :email, type: :string
  required :age, type: :integer
  required :active, type: :boolean, default: true

  optional :metadata, type: :hash, default: {}
  optional :tags, type: :array, default: []

  def call
    context.user = User.create!(
      email: email,
      age: age,
      active: active,
      metadata: metadata,
      tags: tags
    )
  end
end
```

## Execution

Execute tasks using class methods that return result objects or raise exceptions:

```ruby
# Safe execution - returns Result object
result = ProcessOrderTask.call(order_id: 123)

# Exception-based execution - raises on failure/skip
result = ProcessOrderTask.call!(order_id: 123, send_email: false)
```

> [!IMPORTANT]
> Use `call` for conditional logic based on results, and `call!` for exception-based control flow where failures should halt execution.

### Input Coercion

Parameters automatically coerce string inputs to specified types:

```ruby
# String inputs automatically converted
ProcessOrderTask.call(
  order_id: "123",      # → 123 (Integer)
  send_email: "false"   # → false (Boolean)
)
```

## Result Handling

Results provide comprehensive execution information including status, context data, and metadata:

```ruby
result = ProcessOrderTask.call(order_id: 123)

case result.status
when 'success'
  order = result.context.order
  redirect_to order_path(order), notice: "Order processed successfully!"

when 'skipped'
  reason = result.metadata[:reason]
  redirect_to order_path(123), notice: "Skipped: #{reason}"

when 'failed'
  error_details = result.metadata[:reason]
  redirect_to orders_path, alert: "Processing failed: #{error_details}"
end

# Access execution metadata
puts "Runtime: #{result.runtime}ms"
puts "Task ID: #{result.id}"
puts "Executed at: #{result.executed_at}"
```

### Result Properties

| Property | Description | Example |
|----------|-------------|---------|
| `status` | Execution outcome | `'success'`, `'failed'`, `'skipped'` |
| `context` | Shared data object | `result.context.order` |
| `metadata` | Additional details | `result.metadata[:reason]` |
| `runtime` | Execution time (ms) | `result.runtime` |
| `id` | Unique task execution ID | `result.id` |

## Exception Handling

> [!WARNING]
> `call!` raises exceptions for failed or skipped tasks. Use this pattern when failures should halt program execution.

```ruby
begin
  result = ProcessOrderTask.call!(order_id: 123)
  redirect_to order_path(result.context.order), notice: "Order processed!"

rescue CMDx::Skipped => e
  reason = e.result.metadata[:reason]
  redirect_to orders_path, notice: "Skipped: #{reason}"

rescue CMDx::Failed => e
  error_details = e.result.metadata[:reason]
  redirect_to order_path(123), alert: "Failed: #{error_details}"

rescue ActiveRecord::RecordNotFound
  redirect_to orders_path, alert: "Order not found"
end
```

### Exception Types

- **`CMDx::Skipped`** - Task was skipped intentionally
- **`CMDx::Failed`** - Task failed due to business logic or validation errors
- **Standard exceptions** - Ruby/Rails exceptions (e.g., `ActiveRecord::RecordNotFound`)

## Building Workflows

> [!TIP]
> Workflows orchestrate multiple tasks with automatic context sharing, error handling, and execution flow control.

```ruby
class OrderProcessingWorkflow < CMDx::Workflow
  required :order_id, type: :integer
  optional :priority, type: :string, default: 'standard'

  before_execution :log_workflow_start
  on_failed :notify_support
  on_skipped :log_skip_reason

  process ValidateOrderTask
  process ChargePaymentTask
  process UpdateInventoryTask
  process SendConfirmationTask, if: proc { context.payment_successful? }
  process ExpressShippingTask, if: proc { priority == 'express' }

  private

  def log_workflow_start
    Rails.logger.info "Starting order processing for order #{order_id}"
  end

  def notify_support
    SupportNotifier.alert("Order workflow failed",
      order_id: order_id,
      error: result.metadata[:reason]
    )
  end

  def log_skip_reason
    Rails.logger.warn "Workflow skipped: #{result.metadata[:reason]}"
  end
end

# Execute workflow
result = OrderProcessingWorkflow.call(order_id: 123, priority: 'express')
```

### Workflow Features

- **Automatic context sharing** - Tasks access shared `context` object
- **Conditional execution** - Use `:if` conditions for optional tasks
- **Lifecycle callbacks** - Hook into workflow execution phases
- **Error propagation** - Failed tasks halt workflow execution
- **Skip handling** - Graceful handling of skipped tasks

## Code Generation

Generate properly structured tasks and workflows:

```ruby
# Generate individual task
rails generate cmdx:task ProcessOrder
# Creates: app/cmds/process_order_task.rb

# Generate workflow
rails generate cmdx:workflow OrderProcessing
# Creates: app/cmds/order_processing_workflow.rb

# Generate with parameters
rails generate cmdx:task CreateUser email:string age:integer active:boolean
```

> [!NOTE]
> Generators automatically handle naming conventions and inherit from `ApplicationTask`/`ApplicationWorkflow` when available. Generated files include parameter definitions and basic structure.

### Generated Task Structure

```ruby
# app/cmds/process_order_task.rb
class ProcessOrderTask < ApplicationTask
  required :order_id, type: :integer

  def call
    # Task implementation
  end
end
```

---

- **Next:** [Configuration](configuration.md)
- **See also:** [Parameters - Coercions](parameters/coercions.md) | [Workflows](workflows.md)
