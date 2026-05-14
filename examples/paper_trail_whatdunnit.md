# Paper Trail Whatdunnit

When a row changes in production, the version record needs to point at *what* changed it. For HTTP requests PaperTrail handles this automatically; for changes that originate in a CMDx task — a webhook, a scheduled job, a workflow step — the task class itself is the right answer to "whatdunnit".

## Setup

```ruby
# app/middlewares/cmdx_paper_trail_middleware.rb
# frozen_string_literal: true

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

```sql
SELECT whodunnit, object_changes FROM versions WHERE item_id = 42;
-- whodunnit | object_changes
-- ----------+----------------------------------------------------
-- (NULL)    | { "canceled_at": [null, "2026-05-13T..."], ... }

SELECT controller_info->>'whatdunnit' FROM versions WHERE item_id = 42;
-- "CancelSubscription"
```

## Notes

!!! note "Restore in ensure"

    Saving and restoring the previous value keeps nested tasks from leaking their `whatdunnit` into the parent's writes when the chain unwinds — `RegisterUser` calling `SendWelcomeEmail` shouldn't see `SendWelcomeEmail` on the user row's version.
