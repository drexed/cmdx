# Paper Trail Whatdunnit

Paper Trail answers two questions when a row changes: **who** did it (`whodunnit`) and **what code path** was responsible (`whatdunnit` in `controller_info`).

For a normal browser request, Rails sets that up for you. For a CMDx task — a webhook handler, a nightly job, a workflow step — *you* are the code path. Stamping the task class name on each write makes audit logs honest.

## Setup

Middleware sets `whatdunnit` for the duration of the task and restores the previous value when the task finishes. That way nested tasks do not leak their name into the parent's writes.

```ruby
class CmdxPaperTrailMiddleware
  def call(task)
    PaperTrail.request.controller_info ||= {}
    previous = PaperTrail.request.controller_info[:whatdunnit]
    PaperTrail.request.controller_info[:whatdunnit] = task.class.name

    yield
  ensure
    PaperTrail.request.controller_info[:whatdunnit] = previous
  end
end
```

## Usage

Register the middleware on the task (or on `ApplicationTask` if every task should be attributed).

```ruby
class CancelSubscription < CMDx::Task
  register :middleware, CmdxPaperTrailMiddleware.new

  required :subscription_id, coerce: :integer
  required :reason,          coerce: :string

  def work
    subscription = Subscription.find(subscription_id)
    subscription.update!(canceled_at: Time.current, cancel_reason: reason)
  end
end
```

## What to expect

After the task runs, version rows can point at the task class:

```sql
SELECT whodunnit, object_changes FROM versions WHERE item_id = 42;
-- whodunnit | object_changes
-- ----------+----------------------------------------------------
-- (NULL)    | { "canceled_at": [null, "2026-05-13T..."], ... }

SELECT controller_info->>'whatdunnit' FROM versions WHERE item_id = 42;
-- "CancelSubscription"
```

Set `whodunnit` separately (for example `current_user.id`) if you also need a human actor on the version.

## Notes

### Restore in ensure

`RegisterUser` calling `SendWelcomeEmail` should not leave `SendWelcomeEmail` on the user row's version. Saving and restoring `whatdunnit` in `ensure` keeps parent and child tasks from stepping on each other.
