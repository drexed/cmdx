# Internationalization (i18n)

CMDx provides comprehensive internationalization support for all error messages, parameter validation failures, coercion errors, and fault messages. All user-facing text is automatically localized based on the current `I18n.locale`, ensuring your applications can serve global audiences with native-language error reporting.

## Table of Contents

- [Localization](#localization)
- [I18n](#i18n)

## Localization

> [!NOTE]
> CMDx automatically localizes all error messages based on your application's `I18n.locale` setting.

```ruby
class ProcessOrder < CMDx::Task
  attribute :amount, type: :float

  def work
    # Your logic here...
  end
end

I18n.with_locale(:fr) do
  result = ProcessOrder.execute(amount: "invalid")
  result.metadata[:messages][:amount] #=> ["impossible de contraindre en float"]
end
```

## I18n

Install the `cmdx-i18n` gem to add more locale support.

---

- **Prev:** [Logging](logging.md)
- **Next:** [Testing](testing.md)
