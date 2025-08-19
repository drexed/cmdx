# Callbacks

Callbacks provide precise control over task execution lifecycle, running custom logic at specific transition points. Callback callables have access to the same context and result information as the `execute` method, enabling rich integration patterns.

## Table of Contents

- [Hooks](#hooks)
- [Declarations](#declarations)
  - [Symbol](#symbol)
  - [Proc or Lambda](#proc-or-lambda)
  - [Class or Module](#class-or-module)
  - [Conditionals](#conditionals)

## Hooks

Callbacks execute in precise lifecycle order. Multiple callbacks of the same type execute in declaration order (FIFO: first in, first out). Here is a list of available callbacks and which order they get executed:

```ruby
1. before_validation           # Pre-validation setup
2. before_execution            # Setup and preparation
# Task work executed
3. on_[complete|interrupted]   # Based on execution state
4. on_executed                 # Task finished (any outcome)
5. on_[success|skipped|failed] # Based on execution status
6. on_[good|bad]               # Based on outcome classification
```

## Declarations

### Symbol

```ruby
class ProcessOrder < CMDx::Task
  before_execution :find_order

  def work
    # Your logic here...
  end

  private

  def find_order
    @order ||= Order.find(context.order_id)
  end
end
```

### Proc or Lambda

```ruby
class ProcessOrder < CMDx::Task
  # Proc
  on_interrupted proc { BuildLine.stop! }

  # Lambda
  on_complete -> { BuildLine.resume! }
end
```

### Class or Module

```ruby
class SendNotificationCallback
  def call(task)
    if task.result.success?
      EmailApi.deliver_success_email(task.context.user)
    else
      EmailApi.deliver_issue_email(task.context.admin)
    end
  end
end

class ProcessOrder < CMDx::Task
  # Class or Module
  on_success SendNotificationCallback

  # Instance
  on_interrupted SendNotificationCallback.new
end
```

### Conditionals

```ruby
class AbilityCheck
  def call(task)
    task.context.user.can?(:send_email)
  end
end

class ProcessOrder < CMDx::Task
  # If and/or Unless
  before_execution :notify_customer, if: :email_available?, unless: :email_temporary?

  # Proc
  on_failure :increment_failure, if: ->(task) { Rails.env.production? && task.class.name.include?("Legacy") }

  # Lambda
  on_success :ping_warehouse, if: proc { |task| task.context.products_on_backorder? }

  # Class or Module
  on_complete :send_notification, unless: AbilityCheck

  # Instance
  on_complete :send_notification, if: AbilityCheck.new

  def work
    # Your logic here...
  end

  private

  def email_available?
    context.user.email.present?
  end

  def email_temporary?
    context.user.email_service == :temporary
  end
end
```

---

- **Prev:** [Parameters - Defaults](parameters/defaults.md)
- **Next:** [Middlewares](middlewares.md)
