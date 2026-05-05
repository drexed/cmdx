# Callbacks

Run custom logic at specific points during task execution. Callbacks have full access to the task and its context — perfect for logging, notifications, and cleanup.

Note

`task.result` isn't available inside callbacks (the `Result` isn't built yet). Use `on_success` / `on_failed` / `on_skipped`, or subscribe to the `:task_executed` telemetry event for the finalized result.

See [Global Configuration](https://drexed.github.io/cmdx/configuration/#callbacks) for framework-wide callback setup.

Important

Callbacks execute in declaration order (FIFO). Multiple callbacks of the same type run sequentially.

## Available Callbacks

Callbacks execute in a predictable lifecycle order:

```ruby
1. before_execution            # Prepare for execution
2. around_execution            # Wraps everything below; must invoke its continuation
3. before_validation           # Pre-validation setup

# --- inputs resolved, Task#work runs (with retries), outputs verified ---
# --- #rollback runs here when failed ---

4. after_execution             # Execution teardown
5. on_[complete|interrupted]   # State-based (execution lifecycle)
6. on_[success|skipped|failed] # Status-based (business outcome)
7. on_[ok|ko]                  # Outcome-based (success/skip vs fail)
```

Callbacks are additive, not exclusive

Status and outcome callbacks dispatch independently — defining both fires both. A skipped task fires `on_ok` **and** `on_ko`:

| Status  | Fires                          |
| ------- | ------------------------------ |
| success | `on_success`, `on_ok`          |
| skipped | `on_skipped`, `on_ok`, `on_ko` |
| failed  | `on_failed`, `on_ko`           |

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

## Around Callbacks

`around_execution` wraps `before_validation`, `Task#work`, any `#rollback`, and `after_execution` in a single hook. Each callback **must invoke its continuation exactly once** — failure to do so raises `CMDx::CallbackError`. Multiple `around_execution` hooks nest in declaration order (outer-first).

The continuation surface differs by callback form:

- **Symbol** — the instance method receives the continuation as its block; use `yield` (or capture `&blk` and call it):

  ```ruby
  class ProcessBooking < CMDx::Task
    around_execution :instrument

    private

    def instrument
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
    ensure
      Metrics.record(self.class.name, Process.clock_gettime(Process::CLOCK_MONOTONIC) - started)
    end
  end
  ```

- **Proc / Lambda / block** — receives `(task, continuation)`; call `continuation.call`:

  ```ruby
  class ProcessBooking < CMDx::Task
    around_execution ->(task, cont) {
      ActiveRecord::Base.transaction { cont.call }
    }
  end
  ```

- **Class or instance callable** — `#call(task, continuation)`:

  ```ruby
  class WithRequestStore
    def self.call(task, continuation)
      RequestStore.store[:tid] = task.tid
      continuation.call
    ensure
      RequestStore.clear!
    end
  end

  class ProcessBooking < CMDx::Task
    around_execution WithRequestStore
  end
  ```

`around_execution` runs **inside** registered middlewares but **outside** the state/status callbacks (`on_complete`, `on_success`, etc.), so its "after"-portion still observes the result-producing signal but cannot affect which `on_*` callbacks fire. Use it for symmetric concerns like transactions, instrumentation, and per-task logging context. Use a middleware when the wrapping logic must also straddle telemetry/deprecation events.

## Callback Removal

`deregister :callback, event` drops **every** callback for the event. Pass an optional callable to drop only matching entries — matched by `==`, which works for Symbol method names and classes/modules (Procs/Lambdas match by identity, so you must hold the original reference). Unknown events raise `ArgumentError`; unknown callables are a silent no-op.

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

Note

Procs and Lambdas are matched by identity, so removing them requires holding the original reference:

```ruby
HOOK = ->(task) { Audit.log(task) }

class ProcessBooking < CMDx::Task
  on_success HOOK
  deregister :callback, :on_success, HOOK   # works
  # deregister :callback, :on_success, ->(task) { Audit.log(task) }  # would NOT match
end
```
