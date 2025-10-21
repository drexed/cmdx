# Attributes - Transformations

Modify attribute values after coercion but before validation. Perfect for normalization, formatting, and data cleanup.

## Declarations

### Symbol References

Reference instance methods by symbol for dynamic value transformations:

```ruby
class ProcessAnalytics < CMDx::Task
  attribute :options, transform: :compact_blank
end
```

### Proc or Lambda

Use anonymous functions for dynamic value transformations:

```ruby
class CacheContent < CMDx::Task
  # Proc
  attribute :expire_hours, transform: proc { |v| v * 2 }

  # Lambda
  attribute :compression, transform: ->(v) { v.to_s.upcase.strip[0..2]  }
end
```

### Class or Module

Use any object that responds to `call` for reusable transformation logic:

```ruby
class EmailNormalizer
  def call(value)
    value.to_s.downcase.strip
  end
end

class ProcessContacts < CMDx::Task
  # Class or Module
  attribute :email, transform: EmailNormalizer

  # Instance
  attribute :email, transform: EmailNormalizer.new
end
```

## Validations

Validations run on transformed values, ensuring data consistency:

```ruby
class ScheduleBackup < CMDx::Task
  # Coercions
  attribute :retention_days, type: :integer, transform: proc { |v| v.clamp(1, 5) }

  # Validations
  optional :frequency, transform: :downcase, inclusion: { in: %w[hourly daily weekly monthly] }
end
```
