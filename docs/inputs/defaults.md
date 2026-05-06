# Inputs - Defaults

Defaults answer: **“If nobody passed this (or they passed `nil`), what should we use instead?”** They run in the normal pipeline with coercion and validation, so a default isn’t a free pass — it still has to pass your rules.

## Declarations

Defaults play nicely with coercion, validation, and nested inputs.

### Static values

The boring (good!) kind: literals and empty collections.

```ruby
class OptimizeDatabase < CMDx::Task
  input :strategy, default: :incremental
  input :level, default: "basic"
  input :notify_admin, default: true
  input :timeout_minutes, default: 30
  input :indexes, default: []
  input :options, default: {}

  def work
    strategy        #=> :incremental
    level           #=> "basic"
    notify_admin    #=> true
    timeout_minutes #=> 30
    indexes         #=> []
    options         #=> {}
  end
end
```

### Symbol references

Delegate to an instance method when the fallback depends on context:

```ruby
class ProcessAnalytics < CMDx::Task
  input :granularity, default: :default_granularity

  def work
    # ...
  end

  private

  def default_granularity
    Current.user.premium? ? "hourly" : "daily"
  end
end
```

### Proc or Lambda

Tiny bits of logic without naming a method:

```ruby
class CacheContent < CMDx::Task
  input :expire_hours, default: proc { Current.tenant.cache_duration || 24 }
  input :compression, default: -> { Current.tenant.premium? ? "gzip" : "none" }
end
```

### Class or Module

Anything with `#call(task)` can compute the fallback:

```ruby
class TenantDefaults
  def self.call(task)
    Current.tenant.cache_duration || 24
  end
end

class CacheContent < CMDx::Task
  input :expire_hours, default: TenantDefaults
end
```

## Coercions and validations

After a default applies, the value walks the same path as user input: coerce → transform → validate.

```ruby
class ScheduleBackup < CMDx::Task
  input :retention_days, default: "7", coerce: :integer
  input :frequency, default: "daily", inclusion: { in: %w[hourly daily weekly monthly] }
end
```

!!! note

    Defaults trigger when the resolved value is **`nil`**. That includes “key missing” **and** “caller explicitly sent `nil`” — both count as “not really provided.”

!!! warning "Required + default = awkward"

    **`required:` does not wait for defaults.** If the key is missing, you get `is required` before defaults run. So `required: true, default: ...` fights itself: use `optional ..., default:` when you want a fallback, and `required:` when the caller must **name** the key.
