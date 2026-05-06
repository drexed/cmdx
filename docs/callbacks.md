# Callbacks

Callbacks are little hooks CMDx runs for you at fixed moments while a task runs. Want to log something, ping Slack, or tidy up after `work`? That’s what they’re for. You get the task and its context, so you can read inputs and side effects — just remember you’re still *inside* the run, not after the final `Result` exists yet.

!!! note

    Inside a callback, `task.result` is not a thing yet (CMDx hasn’t finished building the `Result`). For “after we know how it went,” use `on_success`, `on_failed`, `on_skipped`, or listen to the `:task_executed` telemetry event — that one carries the finished result.

Want defaults for every task? See [Global Configuration](configuration.md#callbacks).

!!! warning "Heads up"

    Callbacks run in the order you declare them (first in, first out). If you register three `before_execution` hooks, they run one after another — no magic reordering.

## What callbacks exist?

Picture the lifecycle like a sandwich:

```ruby
1. before_execution            # “We’re about to start.”
2. before_validation           # “Inputs are next; do any prep.”
3. around_execution            # Wraps the real work (and rollback). You *must* call the continuation once.

# --- CMDx resolves inputs, runs Task#work (retries if configured), checks outputs ---
# --- If something fails, #rollback runs in here too ---

4. after_execution             # “Work (and maybe rollback) is done.”
5. on_[complete|interrupted]   # About *how* execution ended (lifecycle state)
6. on_[success|skipped|failed] # About *business* outcome (status)
7. on_[ok|ko]                  # Coarse “good vs not purely success” buckets
```

!!! note "Two families, both can fire"

    “Status” callbacks (`on_success`, …) and “outcome” callbacks (`on_ok`, `on_ko`) are **separate channels**. If you define both, both can run for the same task. A **skipped** task is the quirky one: it hits `on_skipped`, `on_ok`, **and** `on_ko` (skipped is “ok-ish” but also “not a clean success”).

    | Status   | Fires                                  |
    |----------|----------------------------------------|
    | success  | `on_success`, `on_ok`                  |
    | skipped  | `on_skipped`, `on_ok`, `on_ko`         |
    | failed   | `on_failed`, `on_ko`                   |

## How do I register one?

### Point at a method (symbol)

The classic move: name a private method, keep the class readable.

```ruby
class ProcessBooking < CMDx::Task
  before_execution :find_reservation

  # You can pass several symbols at once for any callback type
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

### Inline with a Proc or Lambda

Great for one-liners you don’t want as named methods.

```ruby
class ProcessBooking < CMDx::Task
  # Proc
  on_interrupted proc { ReservationSystem.pause! }

  # Lambda
  on_complete -> { ReservationSystem.resume! }
end
```

### A class or module with `#call(task)`

Extract shared behavior so several tasks can reuse it.

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
  # Pass the class (CMDx will instantiate as needed) or an instance
  on_success BookingConfirmationCallback

  on_interrupted BookingIssueCallback.new
end
```

### Only sometimes? Use `if` / `unless`

Same shapes you already saw (symbol, proc, class) — just add a guard.

```ruby
class MessagingPermissionCheck
  def call(task)
    task.context.guest.can?(:receive_messages)
  end
end

class ProcessBooking < CMDx::Task
  # Symbol guards call methods on the task
  before_execution :notify_guest, if: :messaging_enabled?, unless: :messaging_blocked?

  # Proc / lambda / class all work too
  on_failed :increment_failure, if: -> { Rails.env.production? && self.class.name.include?("Legacy") }

  on_success :ping_housekeeping, if: proc { context.rooms_need_cleaning? }

  on_complete :send_confirmation, unless: MessagingPermissionCheck

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

## `around_execution` — the “wrap the whole thing” hook

`around_execution` sits around `Task#work` **and** any `#rollback`, in one place. Think **database transaction** or **timer**: open before, `yield` / `continuation.call` for the real work, close after.

Order-wise: `before_validation` runs before the around-block; `after_execution` runs after the around-block finishes. Each around callback **must** run the continuation **exactly once** — forget that and you get `CMDx::CallbackError`. Several `around_execution` hooks **nest** like Russian dolls: outermost declared first runs outermost.

How you call the continuation depends on how you registered the callback:

- **Symbol method** — Ruby passes the continuation as a block; use `yield` (or `&blk` and `blk.call`):

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

- **Proc / lambda / literal block** — you get `(task, continuation)`; call `continuation.call`:

    ```ruby
    class ProcessBooking < CMDx::Task
      around_execution ->(task, cont) {
        ActiveRecord::Base.transaction { cont.call }
      }
    end
    ```

- **Callable class** — implement `call(task, continuation)`:

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

**Where this sits in the stack:** `around_execution` runs **inside** global middleware, but **outside** the `on_complete` / `on_success` / … family. So you can observe timing and errors, but you don’t get to “vote” on which `on_*` fires — use middleware if you need to wrap telemetry or deprecation too.

## Removing callbacks (`deregister`)

`deregister :callback, event` wipes **every** callback for that event on the class (including inherited ones). Pass a second argument to remove only one “match” — matching uses `==` (works great for symbols and classes; for Procs/Lambdas you need the **same object** you registered).

Unknown event → `ArgumentError`. Unknown callable → quietly does nothing (nothing to remove).

```ruby
class ProcessBooking < CMDx::Task
  # Drop all :before_execution hooks
  deregister :callback, :before_execution

  # Drop only the :notify_guest method hook
  deregister :callback, :before_execution, :notify_guest

  # Drop only this class-based callback
  deregister :callback, :on_complete, BookingConfirmationCallback
end
```

!!! note

    Procs and lambdas match by **identity**. Keep a constant if you want to remove them later:

    ```ruby
    HOOK = ->(task) { Audit.log(task) }

    class ProcessBooking < CMDx::Task
      on_success HOOK
      deregister :callback, :on_success, HOOK   # works
      # deregister :callback, :on_success, ->(task) { Audit.log(task) }  # new lambda — won’t match
    end
    ```
