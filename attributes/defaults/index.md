# Attributes - Defaults

Provide fallback values for optional attributes. Defaults kick in when values aren't provided or are `nil`.

## Declarations

Defaults work seamlessly with coercions, validations, and nested attributes:

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

Defaults follow the same coercion and validation rules as provided values:

```ruby
class ScheduleBackup < CMDx::Task
  # Coercions
  attribute :retention_days, default: "7", type: :integer

  # Validations
  optional :frequency, default: "daily", inclusion: { in: %w[hourly daily weekly monthly] }
end
```
