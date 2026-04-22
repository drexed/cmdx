# Inputs - Defaults

Provide fallback values for optional inputs. Defaults kick in when values aren't provided or are `nil`.

## Declarations

Defaults work seamlessly with coercions, validations, and nested inputs:

### Static Values

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

### Symbol References

Reference instance methods by symbol for dynamic default values:

```ruby
class ProcessAnalytics < CMDx::Task
  input :granularity, default: :default_granularity

  def work
    # Your logic here...
  end

  private

  def default_granularity
    Current.user.premium? ? "hourly" : "daily"
  end
end
```

### Proc or Lambda

Use anonymous functions for dynamic default values:

```ruby
class CacheContent < CMDx::Task
  # Proc
  input :expire_hours, default: proc { Current.tenant.cache_duration || 24 }

  # Lambda
  input :compression, default: -> { Current.tenant.premium? ? "gzip" : "none" }
end
```

### Class or Module

Any object responding to `#call(task)` works as a default:

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

## Coercions and Validations

Defaults flow through the same pipeline as provided values — coercion, transform, then validation:

```ruby
class ScheduleBackup < CMDx::Task
  # Default is coerced through :integer
  input :retention_days, default: "7", coerce: :integer

  # Default is validated against the inclusion list
  input :frequency, default: "daily", inclusion: { in: %w[hourly daily weekly monthly] }
end
```

!!! note

    Defaults only apply when the resolved value is `nil`. An explicitly provided `nil` is treated as missing and the default fires.

!!! warning "Required + default"

    Defaults **do not** satisfy `required:`. A required input whose key is absent fails with `is required` before the default is consulted — so `required: true, default: ...` is effectively a contradiction. Use `optional ..., default:` instead when you want a fallback, and reserve `required:` for keys the caller must explicitly supply.
