# Callbacks

Callbacks provide precise control over task execution lifecycle, running custom logic at specific transition points. Callback callables have access to the same context and result information as the `execute` method, enabling rich integration patterns.

> **Note:** Callbacks execute in the order they are declared within each hook type. Multiple callbacks of the same type execute in declaration order (FIFO: first in, first out).

## Table of Contents

- [Available Callbacks](#available-callbacks)
- [Declarations](#declarations)
  - [Symbol References](#symbol-references)
  - [Proc or Lambda](#proc-or-lambda)
  - [Class or Module](#class-or-module)
  - [Conditional Execution](#conditional-execution)
- [Callback Removal](#callback-removal)

## Available Callbacks

Callbacks execute in precise lifecycle order. Here is the complete execution sequence:

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

### Symbol References

Reference instance methods by symbol for simple callback logic:

```ruby
class ProcessOrder < CMDx::Task
  before_execution :find_order

  # Batch declarations (works for any type)
  on_complete :notify_customer, :update_inventory

  def work
    # Your logic here...
  end

  private

  def find_order
    @order ||= Order.find(context.order_id)
  end

  def notify_customer
    CustomerNotifier.call(context.user, result)
  end

  def update_inventory
    InventoryService.update(context.product_ids, result)
  end
end
```

### Proc or Lambda

Use anonymous functions for inline callback logic:

```ruby
class ProcessOrder < CMDx::Task
  # Proc
  on_interrupted proc { |task| BuildLine.stop! }

  # Lambda
  on_complete -> { BuildLine.resume! }
end
```

### Class or Module

Implement reusable callback logic in dedicated classes:

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

### Conditional Execution

Control callback execution with conditional logic:

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

## Callback Removal

Remove callbacks at runtime for dynamic behavior control:

```ruby
class ProcessOrder < CMDx::Task
  # Symbol
  deregister :callback, :before_execution, :notify_customer

  # Class or Module (no instances)
  deregister :callback, :on_complete, SendNotificationCallback
end
```

> [!IMPORTANT]
> Only one removal operation is allowed per `deregister` call. Multiple removals require separate calls.

---

- **Prev:** [Attributes - Defaults](attributes/defaults.md)
- **Next:** [Middlewares](middlewares.md)
