# Internationalization (i18n)

CMDx provides comprehensive internationalization support for all error messages, including parameter coercion errors, validation failures, and fault messages. All error text is automatically localized based on the current `I18n.locale`.

## Table of Contents

- [TLDR](#tldr)
- [Available Locales](#available-locales)
- [Fault Messages](#fault-messages)
- [Parameter Messages](#parameter-messages)
- [Coercion Messages](#coercion-messages)
- [Validation Messages](#validation-messages)

## TLDR

- **24 languages** - Built-in translations for major world languages
- **Automatic localization** - Based on `I18n.locale` setting
- **Complete coverage** - Coercion errors, validation failures, and fault messages
- **Custom overrides** - Parameter-specific messages override locale defaults

## Available Locales

CMDx includes built-in translations for 24 languages:

| Language | Locale | Language | Locale |
|----------|--------|----------|--------|
| English | `:en` | Russian | `:ru` |
| Spanish | `:es` | Arabic | `:ar` |
| French | `:fr` | Korean | `:ko` |
| German | `:de` | Dutch | `:nl` |
| Portuguese | `:pt` | Swedish | `:sv` |
| Italian | `:it` | Hindi | `:hi` |
| Japanese | `:ja` | Polish | `:pl` |
| Chinese | `:zh` | Turkish | `:tr` |
| Norwegian | `:no` | Danish | `:da` |
| Finnish | `:fi` | Greek | `:el` |
| Hebrew | `:he` | Thai | `:th` |
| Vietnamese | `:vi` | Czech | `:cs` |

## Fault Messages

Default fault messages from `skip!` and `fail!` methods are localized:

```ruby
class ProcessPaymentTask < CMDx::Task
  def call
    # When no reason is provided, uses localized default
    fail! if payment_declined?
  end
end

# English
I18n.locale = :en
result = ProcessPaymentTask.call(payment_id: 123)
result.metadata[:reason] #=> "no reason given"

# Chinese
I18n.locale = :zh
result = ProcessPaymentTask.call(payment_id: 123)
result.metadata[:reason] #=> "未提供原因"
```

## Parameter Messages

Parameter required or undefined source errors are automatically localized:

```ruby
class ProcessOrderTask < CMDx::Task
  required :order_id, type: :integer
  optional :user_name, source: :nonexistent_method

  def call
    # Task implementation
  end
end

# English locale
I18n.locale = :en
result = ProcessOrderTask.call({}) # Missing required parameter
result.metadata[:messages][:order_id] #=> ["is a required parameter"]

result = ProcessOrderTask.call(order_id: 123) # Undefined source method
result.metadata[:messages][:user_name] #=> ["delegates to undefined method nonexistent_method"]

# Spanish locale
I18n.locale = :es
result = ProcessOrderTask.call({}) # Missing required parameter
result.metadata[:messages][:order_id] #=> ["es un parámetro requerido"]

result = ProcessOrderTask.call(order_id: 123) # Undefined source method
result.metadata[:messages][:user_name] #=> ["delegado al método indefinido nonexistent_method"]
```

## Coercion Messages

Type conversion errors are automatically localized:

```ruby
class ProcessOrderTask < CMDx::Task
  required :order_id, type: :integer
  required :amount, type: :float

  def call
    # Task implementation
  end
end

# English
I18n.locale = :en
result = ProcessOrderTask.call(order_id: "invalid", amount: "bad")
result.metadata[:messages][:order_id] #=> ["could not coerce into an integer"]

# Spanish
I18n.locale = :es
result = ProcessOrderTask.call(order_id: "invalid", amount: "bad")
result.metadata[:messages][:order_id] #=> ["no podía coacciona el valor a un integer"]
```

## Validation Messages

All validator error messages support internationalization:

```ruby
class RegisterUserTask < CMDx::Task
  required :email, format: { with: /@/ }
  required :age, numeric: { min: 18 }
  required :status, inclusion: { in: %w[active inactive] }

  def call
    # Task implementation
  end
end

# English
I18n.locale = :en
result = RegisterUserTask.call(email: "invalid", age: 16, status: "unknown")
result.metadata[:messages][:email] #=> ["is an invalid format"]

# Japanese
I18n.locale = :ja
result = RegisterUserTask.call(email: "invalid", age: 16, status: "unknown")
result.metadata[:messages][:email] #=> ["無効な形式です"]
```

---

- **Prev:** [Logging](logging.md)
- **Next:** [Testing](testing.md)
