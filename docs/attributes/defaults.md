# Attributes - Defaults

Attribute defaults provide fallback values when arguments are not provided or resolve to `nil`. Defaults ensure tasks have sensible values for optional attributes while maintaining flexibility for callers to override when needed.

## Declarations

Defaults apply when attributes are not provided or resolve to `nil`. They work seamlessly with coercion, validation, and nested attributes.

### Static Values

```ruby
class OptimizeDatabase < CMDx::Task
  attribute :strategy, default: :incremental
  attribute :level, default: "basic"
  attribute :notify_admin, default: true
  attribute :timeout_minutes, default: 30
  attribute :indexes, default: []
  attribute :options, default: {}

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
  attribute :granularity, default: :default_granularity

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
  attribute :expire_hours, default: proc { Current.tenant.cache_duration || 24 }

  # Lambda
  attribute :compression, default: -> { Current.tenant.premium? ? "gzip" : "none" }
end
```

## Coercions and Validations

Defaults are subject to the same coercion and validation rules as provided values, ensuring consistency and catching configuration errors early.

```ruby
class ScheduleBackup < CMDx::Task
  # Coercions
  attribute :retention_days, default: "7", type: :integer

  # Validations
  optional :frequency, default: "daily", inclusion: { in: %w[hourly daily weekly monthly] }
end
```

---

- **Prev:** [Attributes - Validations](validations.md)
- **Next:** [Attributes - Transformations](transformations.md)
