# Callbacks

Run custom logic at specific points during task execution. Callbacks have full access to task context and results, making them perfect for logging, notifications, cleanup, and more.

See [Global Configuration](getting_started.md#callbacks) for framework-wide callback setup.

!!! warning "Important"

    Callbacks execute in declaration order (FIFO). Multiple callbacks of the same type run sequentially.

## Available Callbacks

Callbacks execute in a predictable lifecycle order:

```ruby
1. before_validation           # Pre-validation setup
2. before_execution            # Prepare for execution

# --- Task#work executes ---

3. on_[complete|interrupted]   # State-based (execution lifecycle)
4. on_executed                 # Always runs after work completes
5. on_[success|skipped|failed] # Status-based (business outcome)
6. on_[good|bad]               # Outcome-based (success/skip vs fail)
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
  on_interrupted proc { ReservationSystem.pause! }

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
  on_failure :increment_failure, if: -> { Rails.env.production? && self.class.name.include?("Legacy") }

  # Lambda
  on_success :ping_housekeeping, if: proc { context.rooms_need_cleaning? }

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

Remove unwanted callbacks dynamically:

!!! warning "Important"

    Each `deregister` call removes one callback. Use multiple calls for batch removals.

```ruby
class ProcessBooking < CMDx::Task
  # Symbol
  deregister :callback, :before_execution, :notify_guest

  # Class or Module (no instances)
  deregister :callback, :on_complete, BookingConfirmationCallback
end
```
