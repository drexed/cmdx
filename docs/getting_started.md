# Getting Started

CMDx is a Ruby framework for building maintainable, observable business logic through composable
command objects. Design robust workflows with automatic parameter validation, structured error
handling, comprehensive logging, and intelligent execution flow control that scales from simple
tasks to complex multi-step processes.

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

- **Installation** - Add `gem 'cmdx'` to Gemfile, run `rails g cmdx:install`
- **Tasks** - Ruby classes inheriting from `CMDx::Task` with `call` method
- **Execution** - Use `call` (returns result) or `call!` (raises on failure/skip)
- **Parameters** - Define with `required`/`optional` with type coercion and validation
- **Results** - Check `result.status` for success/skipped/failed outcomes
- **Workflows** - Orchestrate multiple tasks with `CMDx::Workflow`
- **Generators** - Use `rails g cmdx:task` and `rails g cmdx:workflow` for scaffolding

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

# Raises exceptions on failure/skip, else returns Result object
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

## Building Workflows

Combine tasks using workflows:

```ruby
class OrderProcessingWorkflow < CMDx::Workflow
  required :order_id, type: :integer

  before_execution :log_workflow_start
  on_failed :notify_support

  process ValidateOrderTask
  process ChargePaymentTask
  process UpdateInventoryTask
  process SendConfirmationTask, if: proc { context.payment_successful? }

  # NO call method

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

Generate tasks and workflows with proper structure:

```bash
# Generate individual task
rails generate cmdx:task ProcessOrder
# Creates: app/cmds/process_order_task.rb

# Generate task workflow
rails generate cmdx:workflow OrderDeliveryWorkflow
# Creates: app/cmds/order_delivery_workflow.rb
```

> [!NOTE]
> Generators automatically handle naming conventions and inherit from `ApplicationTask`/`ApplicationWorkflow` when available.

---

- **Prev:** [Tips and Tricks](tips_and_tricks.md)
- **Next:** [Configuration](configuration.md)
