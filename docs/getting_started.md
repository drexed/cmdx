# Getting Started

CMDx is a Ruby framework for building maintainable, observable business logic through composable
command objects. Design robust workflows with automatic parameter validation, structured error
handling, comprehensive logging, and intelligent execution flow control that scales from simple
tasks to complex multi-step processes.

## Table of Contents

- [Goals](#goals)
- [Installation](#installation)
- [Quick Setup](#quick-setup)
- [Execution](#execution)
- [Result Handling](#result-handling)
- [Exception Handling](#exception-handling)
- [Building Workflows](#building-workflows)
- [Code Generation](#code-generation)

## Goals

- Easy branching, nesting, and composition of complex tasks
- Supply intent, severity, and reasoning for halting execution
- Demystify root causes with exhaustive tracing

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
> This creates `config/initializers/cmdx.rb` with default settings.

## Quick Setup

Create your first task following the **Verb + Noun + Task** naming convention:

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

> [!TIP]
> Use **present tense verbs** for clarity: `ProcessOrderTask`, `SendEmailTask`, `ValidatePaymentTask`

## Execution

Execute tasks using class methods:

```ruby
# Returns Result object
result = ProcessOrderTask.call(order_id: 123)

# Raises exceptions on failure/skip
result = ProcessOrderTask.call!(order_id: 123, send_email: false)
```

## Result Handling

Check execution outcomes:

```ruby
result = ProcessOrderTask.call(order_id: 123)

case result.status
when 'success'
  redirect_to order_path(result.context.order), notice: "Order processed!"
when 'skipped'
  redirect_to order_path(result.context.order), notice: result.metadata[:reason]
when 'failed'
  redirect_to orders_path, alert: "Error: #{result.metadata[:reason]}"
end

# Access execution metadata
puts "Runtime: #{result.runtime}s, Task ID: #{result.id}"
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
  redirect_to order_path(123), alert: e.result.metadata[:reason]
end
```

> [!WARNING]
> Use `call!` only when you need exception-based flow control. Use `call` for most scenarios.

## Building Workflows

Combine tasks using batches:

```ruby
class ProcessOrderWorkflow < CMDx::Batch
  required :order_id, type: :integer

  process ValidateOrderTask
  process ChargePaymentTask
  process UpdateInventoryTask
  process SendConfirmationTask, if: proc { context.payment_successful? }

  before_execution :log_workflow_start
  on_failed :notify_support

  private

  def log_workflow_start
    Rails.logger.info "Starting order workflow for order #{order_id}"
  end

  def notify_support
    SupportNotifier.alert("Order workflow failed", context: context.to_h)
  end
end

result = ProcessOrderWorkflow.call(order_id: 123)
```

## Code Generation

Generate tasks and batches with proper structure:

```bash
# Generate individual task
rails generate cmdx:task ProcessOrder
# Creates: app/cmds/process_order_task.rb

# Generate workflow batch
rails generate cmdx:batch BatchOrderDeliveries
# Creates: app/cmds/batch_order_deliveries.rb
```

> [!NOTE]
> Generators automatically handle naming conventions and inherit from `ApplicationTask`/`ApplicationBatch` when available.

---

- **Prev:** [Example](https://github.com/drexed/cmdx/blob/main/docs/example.md)
- **Next:** [Configuration](https://github.com/drexed/cmdx/blob/main/docs/configuration.md)
