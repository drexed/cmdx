# Sentry Error Tracking

Report unhandled exceptions and unexpected task failures to Sentry with detailed context.

<https://github.com/getsentry/sentry-ruby>

### Setup

```ruby
# lib/cmdx_sentry_middleware.rb
class CmdxSentryMiddleware
  def self.call(task, **options, &)
    Sentry.with_scope do |scope|
      scope.set_tags(task: task.class.name)
      scope.set_context(:user, Current.user.sentry_attributes)

      yield.tap do |result|
        # Optional: Report logical failures if needed
        if Array(options[:report_on]).include?(result.status)
          Sentry.capture_message("Task #{result.status}: #{result.reason}", level: :warning)
        end
      end
    end
  rescue => e
    Sentry.capture_exception(e)
    raise(e) # Re-raise to let the task handle the error or bubble up
  end
end
```

### Usage

```ruby
class ProcessPayment < CMDx::Task
  # Report exceptions only
  register :middleware, CmdxSentryMiddleware

  # Report exceptions AND logical failures (result.failure?)
  register :middleware, CmdxSentryMiddleware, report_on: %w[failed skipped]

  def work
    # ...
  end
end
```

