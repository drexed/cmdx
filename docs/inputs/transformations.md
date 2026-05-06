# Inputs - Transformations

Transforms are the **tidy-up step**: trim strings, normalize emails, clamp numbers — whatever polish you want **after** coercion but **before** validation. Validators always see the cleaned-up value.

## Processing pipeline

Every input walks the same line:

```mermaid
flowchart LR
    Source --> Default --> Coerce --> Transform --> Validate
```

| Stage | What happens |
|-------|----------------|
| **Source** | Pull raw value from context, method, proc, or callable |
| **Default** | If still `nil`, apply `default:` |
| **Coerce** | Turn into the target type (`coerce:`) |
| **Transform** | Massage the coerced value (`transform:`) |
| **Validate** | Run presence, format, inclusion, etc. |

So: coerce first, then transform, then validate. Plan rules accordingly.

## Declarations

### Symbol references

Call a method on the **value** if it exists (`value.send(symbol)`); otherwise CMDx tries `task.send(symbol, value)`:

```ruby
class ProcessAnalytics < CMDx::Task
  input :options, transform: :compact_blank
end
```

### Proc or Lambda

Inline tweaks without extra classes:

```ruby
class CacheContent < CMDx::Task
  input :expire_hours, transform: proc { |v| v * 2 }
  input :compression, transform: ->(v) { v.to_s.upcase.strip[0..2] }
end
```

### Class or Module

Share logic with `#call(value, task)`:

```ruby
class EmailNormalizer
  def self.call(value, _task)
    value.to_s.downcase.strip
  end
end

class PhoneNormalizer
  def call(value, _task)
    value.to_s.gsub(/\D/, "")
  end
end

class ProcessContacts < CMDx::Task
  input :email, transform: EmailNormalizer
  input :phone, transform: PhoneNormalizer.new
end
```

## Pipeline position

Because validation runs last, you can coerce → fix → then check:

```ruby
class ScheduleBackup < CMDx::Task
  input :retention_days, coerce: :integer, transform: proc { |v| v.clamp(1, 5) }
  optional :frequency, transform: :downcase, inclusion: { in: %w[hourly daily weekly monthly] }
end
```

!!! warning "Optional + nil"

    Transforms only run when the coerced value is **non-`nil`**. If the key is missing, there’s no default, and the input is optional, the pipeline stops early — no transform, no validator. Need the transform every time? Add a `default:` or make the input `required`.
