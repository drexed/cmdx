# Paper Trail Whatdunnit

Tag every [PaperTrail](https://github.com/paper-trail-gem/paper_trail) version record with the task class that caused the change. See [Storing Metadata](https://github.com/paper-trail-gem/paper_trail?tab=readme-ov-file#4c-storing-metadata).

## Setup

```ruby
# app/middlewares/cmdx_paper_trail_middleware.rb
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
class UpdateSubscription < CMDx::Task
  register :middleware, CmdxPaperTrailMiddleware.new

  def work
    # ...
  end
end
```

## Notes

!!! note

    Restoring the previous value in `ensure` keeps nested tasks from leaking their `whatdunnit` back to the caller when the chain unwinds.
