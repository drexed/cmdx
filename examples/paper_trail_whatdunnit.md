# Paper Trail Whatdunnit

Tag paper trail version records with which service made a change with a custom `whatdunnit` attribute.

<https://github.com/paper-trail-gem/paper_trail?tab=readme-ov-file#4c-storing-metadata>

### Setup

```ruby
# lib/cmdx_paper_trail_middleware.rb
class CmdxPaperTrailMiddleware
  def self.call(task, **options, &)
    # This makes sure to reset the whatdunnit value to the previous
    # value for nested task calls

    begin
      PaperTrail.request.controller_info ||= {}
      old_whatdunnit = PaperTrail.request.controller_info[:whatdunnit]
      PaperTrail.request.controller_info[:whatdunnit] = task.class.name
      yield
    ensure
      PaperTrail.request.controller_info[:whatdunnit] = old_whatdunnit
    end
  end
end
```

### Usage

```ruby
class MyTask < CMDx::Task
  register :middleware, CmdxPaperTrailMiddleware

  def work
    # Do work...
  end

end
```
