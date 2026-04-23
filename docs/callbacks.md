# Callbacks

Run custom logic at specific points during task execution. Callbacks have full access to the task and its context — perfect for logging, notifications, and cleanup.

!!! note

    The `Result` isn't built yet when callbacks run, so `task.result` isn't available. Branch on outcome by registering separate `on_success` / `on_failed` / `on_skipped` callbacks, or subscribe to Telemetry's `:task_executed` event when you need the finalized result.

See [Global Configuration](configuration.md#callbacks) for framework-wide callback setup.

!!! warning "Important"

    Callbacks execute in declaration order (FIFO). Multiple callbacks of the same type run sequentially.

## Available Callbacks

Callbacks execute in a predictable lifecycle order:

```ruby
1. before_execution            # Prepare for execution
2. before_validation           # Pre-validation setup

# --- inputs resolved, Task#work runs (with retries), outputs verified ---
# --- #rollback runs here when failed ---

3. on_[complete|interrupted]   # State-based (execution lifecycle)
4. on_[success|skipped|failed] # Status-based (business outcome)
5. on_[ok|ko]                  # Outcome-based (success/skip vs fail)
```

!!! note "Callbacks are additive, not exclusive"

    Status callbacks (`on_success` / `on_skipped` / `on_failed`) and outcome
    callbacks (`on_ok` / `on_ko`) are dispatched independently — if you define
    both kinds, both will fire. The outcome pair also overlaps on skipped
    results: `on_ok` runs for success **and** skipped, `on_ko` runs for skipped
    **and** failed, so a skipped task fires **both** `on_ok` and `on_ko`.

    | Status   | Fires                                  |
    |----------|----------------------------------------|
    | success  | `on_success`, `on_ok`                  |
    | skipped  | `on_skipped`, `on_ok`, `on_ko`         |
    | failed   | `on_failed`, `on_ko`                   |

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
    GuestNotifier.call(context.guest)
  end

  def update_availability
    AvailabilityService.update(context.room_ids)
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

Implement reusable callback logic in dedicated modules and classes:

```ruby
class BookingConfirmationCallback
  def call(task)
    MessagingApi.send_confirmation(task.context.guest)
  end
end

class BookingIssueCallback
  def call(task)
    MessagingApi.send_issue_alert(task.context.manager)
  end
end

class ProcessBooking < CMDx::Task
  # Class or Module
  on_success BookingConfirmationCallback

  # Instance
  on_interrupted BookingIssueCallback.new
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
  on_failed :increment_failure, if: -> { Rails.env.production? && self.class.name.include?("Legacy") }

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

`deregister :callback, event` drops **every** callback for the event. Pass an
optional callable to drop only matching entries — matched by `==`, which works
for Symbol method names and classes/modules (Procs/Lambdas match by identity,
so you must hold the original reference). Unknown events raise `ArgumentError`;
unknown callables are a silent no-op.

```ruby
class ProcessBooking < CMDx::Task
  # Drops every :before_execution callback (inherited or local)
  deregister :callback, :before_execution

  # Drops only the :notify_guest method callback for :before_execution
  deregister :callback, :before_execution, :notify_guest

  # Drops only the BookingConfirmationCallback class for :on_complete
  deregister :callback, :on_complete, BookingConfirmationCallback
end
```

!!! note

    Procs and Lambdas are matched by identity, so removing them requires
    holding the original reference:

    ```ruby
    HOOK = ->(task) { Audit.log(task) }

    class ProcessBooking < CMDx::Task
      on_success HOOK
      deregister :callback, :on_success, HOOK   # works
      # deregister :callback, :on_success, ->(task) { Audit.log(task) }  # would NOT match
    end
    ```
