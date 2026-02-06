---
date: 2026-02-18
authors:
  - drexed
categories:
  - Tutorials
slug: mastering-cmdx-retries-deprecation-i18n
---

# Mastering CMDx: Retries, Deprecation, and Internationalization

As developers, we often obsess over the "happy path"—that perfect scenario where networks never time out, requirements never change, and every user speaks English. But the real world isn't so accommodating. Services fail, code evolves, and your application needs to speak more than just one language.

In this post, I want to dive into three CMDx features that help you handle these realities: **Retries** for resilience, **Deprecation** for lifecycle management, and **Internationalization** for global reach. These tools might seem distinct, but together they elevate your business logic from "functional" to "production-grade."

<!-- more -->

## Retries: Handling Transient Failures

We've all been there: your code is perfect, but the third-party API you depend on is having a bad day. Instead of letting your entire workflow crash because of a temporary blip, CMDx lets you try again.

### Basic Configuration

Adding retries is as simple as defining a setting. By default, CMDx will retry on any `StandardError`.

```ruby
class FetchExchangeRates < CMDx::Task
  settings retries: 3

  def work
    # If this raises, we'll try 3 more times
    context.rates = ExternalRateAPI.fetch_latest
  end
end
```

When I first used this, I watched the logs and saw the automatic retries kick in during a network glitch. It felt like magic—my background job didn't fail, it just persisted until it succeeded.

### Selective Retries

Of course, retrying isn't always the answer. If you get a `401 Unauthorized`, retrying won't fix your bad API key. You can be specific about what triggers a retry:

```ruby
class ProcessPayment < CMDx::Task
  settings retries: 5, retry_on: [NetworkError, Timeout::Error]

  def work
    # Only retries for network issues, not logic errors
    PaymentGateway.charge(context.amount)
  end
end
```

### Adding Jitter (Backoff)

Hammering a struggling service with immediate retries is a recipe for disaster. Adding a delay (jitter) gives the downstream system breathing room. You can use a fixed number, a symbol, or even a proc.

```ruby
class SyncData < CMDx::Task
  # Wait 2 seconds between attempts
  settings retries: 3, retry_jitter: 2.0

  def work
    # ...
  end
end
```

For more complex scenarios, I prefer exponential backoff. You can define a method to calculate the delay based on the retry count:

```ruby
class ResilientSync < CMDx::Task
  settings retries: 5, retry_jitter: :exponential_backoff

  def work
    # ...
  end

  private

  def exponential_backoff(retry_count)
    # 2s, 4s, 8s, 16s...
    2 ** retry_count
  end
end
```

## Deprecation: Evolving Your Codebase

Codebases grow and change. Yesterday's `CreateUser` task might be today's `RegisterAccount`. You can't always delete old code immediately, especially if you have other teams or services relying on it. CMDx provides a structured way to sunset tasks.

### Soft Deprecation with Logging

When I start phasing out a task, I usually begin with logging. The task still runs, but it leaves a paper trail.

```ruby
class CreateUser < CMDx::Task
  settings deprecate: :log

  def work
    # logic ...
  end
end
```

Now, every time `CreateUser` runs, you'll see a warning in your logs. It's a gentle nudge to migrate.

### noisy Deprecation for Developers

For a stronger signal during development, you can use `:warn`. This prints a Ruby warning to stderr, which is hard to miss when running tests or a console session.

```ruby
class CreateUser < CMDx::Task
  settings deprecate: :warn
  # ...
end
```

### Hard Deprecation

Finally, when the deadline passes, you can prevent execution entirely.

```ruby
class CreateUser < CMDx::Task
  settings deprecate: :raise
  # ...
end

# CreateUser.execute => Raises CMDx::DeprecationError
```

You can even make this dynamic! For example, maybe you want to raise errors in development but only log in production:

```ruby
settings deprecate: -> { Rails.env.production? ? :log : :raise }
```

## Internationalization (i18n): Speaking Your User's Language

If you're building a global application with Ruby, you're probably already using the `i18n` gem. CMDx integrates seamlessly with it. This is huge for error messages and validations.

Instead of hardcoding "Price must be positive," CMDx looks up translations based on the current locale.

```ruby
class CreateProduct < CMDx::Task
  attribute :price, type: :integer
  validates :price, numericality: { greater_than: 0 }

  def work
    # ...
  end
end
```

If I run this with an invalid price in a French locale:

```ruby
I18n.with_locale(:fr) do
  result = CreateProduct.execute(price: -10)
  puts result.metadata[:messages][:price]
  # => ["doit être supérieur à 0"]
end
```

CMDx comes with built-in translations for over 90 languages, so standard validation errors work out of the box. You just need to ensure the locale files are loaded in your app.

## Conclusion

These features—retries, deprecation, and internationalization—might seem like "nice-to-haves," but they are what separate a script from a framework. They allow you to write code that is resilient to failure, maintainable over the long term, and accessible to a global audience.

By leaning on CMDx to handle these concerns, you keep your `work` method clean and focused on the actual business logic. And that's always a win.

## References

- [Retries](https://drexed.github.io/cmdx/retries/)
- [Deprecation](https://drexed.github.io/cmdx/deprecation/)
- [Internationalization](https://drexed.github.io/cmdx/internationalization/)
