# Attributes - Transformations

Attribute transformations allow you to alter values on the fly. This allows for value alterations and normalizations.

## Table of Contents

- [Declarations](#declarations)
  - [Symbol References](#symbol-references)
  - [Proc or Lambda](#proc-or-lambda)
- [Coercions and Validations](#coercions-and-validations)

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

## Coercions and Validations

Transformed values are subject to the same coercion and validation rules as untransformed values, ensuring consistency and catching configuration errors early.

```ruby
class ScheduleBackup < CMDx::Task
  # Coercions
  attribute :retention_days, type: :integer, transform: proc { |v| v.clamp(1, 5) }

  # Validations
  optional :frequency, transform: :downcase, inclusion: { in: %w[hourly daily weekly monthly] }
end
```

---

- **Prev:** [Attributes - Transformations](transformations.md)
- **Next:** [Callbacks](../callbacks.md)
