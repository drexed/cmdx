# Attributes - Transformations

Transformations allow you to modify attribute values after they are derived and coerced from their source but before any validations. This enables data normalization, formatting, and conditional processing within the attribute pipeline.

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

Transformed values are subject to the same validation rules as untransformed values, ensuring consistency and catching configuration errors early.

```ruby
class ScheduleBackup < CMDx::Task
  # Coercions
  attribute :retention_days, type: :integer, transform: proc { |v| v.clamp(1, 5) }

  # Validations
  optional :frequency, transform: :downcase, inclusion: { in: %w[hourly daily weekly monthly] }
end
```
