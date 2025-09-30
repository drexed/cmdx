# Callbacks

Callbacks provide precise control over task execution lifecycle, running custom logic at specific transition points. Callback callables have access to the same context and result information as the `execute` method, enabling rich integration patterns.

Check out the [Getting Started](https://github.com/drexed/cmdx/blob/main/docs/getting_started.md#callbacks) docs for global configuration.

> [!IMPORTANT]
> Callbacks execute in the order they are declared within each hook type. Multiple callbacks of the same type execute in declaration order (FIFO: first in, first out).

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

# --- Task#work executed ---

3. on_[complete|interrupted]   # Based on execution state
4. on_executed                 # Task finished (any outcome)
5. on_[success|skipped|failed] # Based on execution status
6. on_[good|bad]               # Based on outcome classification
```

## Declarations

### Symbol References

Reference instance methods by symbol for simple callback logic:

```ruby
class ProcessBooking < CMDx::Task
  before_execution :find_reservation

  # Batch declarations (works for any type)
  on_complete :notify_guest, :update_availability

  def work
    # Your logic here...
  end

  private

  def find_reservation
    @reservation ||= Reservation.find(context.reservation_id)
  end

  def notify_guest
    GuestNotifier.call(context.guest, result)
  end

  def update_availability
    AvailabilityService.update(context.room_ids, result)
  end
end
```

### Proc or Lambda

Use anonymous functions for inline callback logic:

```ruby
class ProcessBooking < CMDx::Task
  # Proc
  on_interrupted proc { |task| ReservationSystem.pause! }

  # Lambda
  on_complete -> { ReservationSystem.resume! }
end
```

### Class or Module

Implement reusable callback logic in dedicated classes:

```ruby
class BookingConfirmationCallback
  def call(task)
    if task.result.success?
      MessagingApi.send_confirmation(task.context.guest)
    else
      MessagingApi.send_issue_alert(task.context.manager)
    end
  end
end

class ProcessBooking < CMDx::Task
  # Class or Module
  on_success BookingConfirmationCallback

  # Instance
  on_interrupted BookingConfirmationCallback.new
end
```

### Conditional Execution

Control callback execution with conditional logic:

```ruby
class MessagingPermissionCheck
  def call(task)
    task.context.guest.can?(:receive_messages)
  end
end

class ProcessBooking < CMDx::Task
  # If and/or Unless
  before_execution :notify_guest, if: :messaging_enabled?, unless: :messaging_blocked?

  # Proc
  on_failure :increment_failure, if: ->(task) { Rails.env.production? && task.class.name.include?("Legacy") }

  # Lambda
  on_success :ping_housekeeping, if: proc { |task| task.context.rooms_need_cleaning? }

  # Class or Module
  on_complete :send_confirmation, unless: MessagingPermissionCheck

  # Instance
  on_complete :send_confirmation, if: MessagingPermissionCheck.new

  def work
    # Your logic here...
  end

  private

  def messaging_enabled?
    context.guest.messaging_preference == true
  end

  def messaging_blocked?
    context.guest.communication_status == :blocked
  end
end
```

## Callback Removal

Remove callbacks at runtime for dynamic behavior control:

> [!IMPORTANT]
> Only one removal operation is allowed per `deregister` call. Multiple removals require separate calls.

```ruby
class ProcessBooking < CMDx::Task
  # Symbol
  deregister :callback, :before_execution, :notify_guest

  # Class or Module (no instances)
  deregister :callback, :on_complete, BookingConfirmationCallback
end
```

---

- **Prev:** [Attributes - Transformations](attributes/transformations.md)
- **Next:** [Middlewares](middlewares.md)
