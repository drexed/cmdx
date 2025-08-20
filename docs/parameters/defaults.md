# Parameters - Defaults

Parameter defaults provide fallback values when arguments are not provided or resolve to `nil`. Defaults ensure tasks have sensible values for optional parameters while maintaining flexibility for callers to override when needed.

## Table of Contents

- [Declarations](#declarations)
  - [Static Values](#static-values)
  - [Symbol References](#symbol-references)
  - [Proc or Lambda](#proc-or-lambda)
- [Coercions and Validations](#coercions-and-validations)

## Declarations

Defaults apply when parameters are not provided or resolve to `nil`. They work seamlessly with coercion, validation, and nested parameters.

### Static Values

```ruby
class ProcessOrder < CMDx::Task
  attribute :charge_type, default: :credit_card
  attribute :priority, default: "standard"
  attribute :send_email, default: true
  attribute :max_retries, default: 3
  attribute :tags, default: []
  attribute :data, default: {}

  def work
    charge_type #=> :credit_card
    priority    #=> "standard"
    send_email  #=> true
    max_retries #=> 3
    tags        #=> []
    data        #=> {}
  end
end
```

### Symbol References

Reference instance methods by symbol for dynamic default values:

```ruby
class ProcessOrder < CMDx::Task
  attribute :priority, default: :default_priority

  def work
    # Your logic here...
  end

  private

  def default_priority
    Current.account.pro? ? "priority" : "standard"
  end
end
```

### Proc or Lambda

Use anonymous functions for dynamic default values:

```ruby
class ProcessOrder < CMDx::Task
  # Proc
  attribute :send_email, default: proc { Current.account.email_api_key? }

  # Lambda
  attribute :priority, default: -> { Current.account.pro? ? "priority" : "standard" }
end
```

## Coercions and Validations

Defaults are subject to the same coercion and validation rules as provided values, ensuring consistency and catching configuration errors early.

```ruby
class ConfigureService < CMDx::Task
  # Coercions
  attribute :retry_count, default: "3", type: :integer

  # Validations
  optional :priority, default: "medium", inclusion: { in: %w[low medium high urgent] }
end
```

---

- **Prev:** [Parameters - Validations](validations.md)
- **Next:** [Callbacks](../callbacks.md)
