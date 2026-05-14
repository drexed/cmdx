# ActiveSupport Instrumentation

Emitting an `ActiveSupport::Notifications` event per task lets the existing Rails subscriber ecosystem (StatsD, Skylight, log subscribers) time and tag tasks alongside controller actions, without bolting another telemetry pipeline onto the app.

## Setup

```ruby
# app/middlewares/cmdx_instrumentation_middleware.rb
# frozen_string_literal: true

class CmdxInstrumentationMiddleware
  def call(task)
    chain = CMDx::Chain.current

    ActiveSupport::Notifications.instrument(
      "execute.cmdx",
      task: task.class.name,
      type: task.class.type,
      tid:  task.tid,
      cid:  chain.id,
      xid:  chain.xid
    ) { yield }
  end
end
```

```ruby
# config/initializers/cmdx_instrumentation.rb
# frozen_string_literal: true

CMDx.configure do |config|
  config.middlewares.register(CmdxInstrumentationMiddleware.new)
end

ActiveSupport::Notifications.subscribe("execute.cmdx") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  Rails.logger.tagged("cmdx", event.payload[:tid]) do
    Rails.logger.info("#{event.payload[:task]} took #{event.duration.round(2)}ms")
  end
end
```

## Usage

```ruby
class Users::Create < CMDx::Task
  required :email, coerce: :string, validate: { format: URI::MailTo::EMAIL_REGEXP }

  def work
    context.user = User.create!(email:)
  end
end
```

## Notes

!!! tip "When the lifecycle event suffices"

    CMDx ships its own `:task_executed` event with `result.duration`, `result.status`, `result.retries`, and the full `Result` already finalized — no event reconstruction needed. Reach for `ActiveSupport::Notifications` only when you need an existing Rails subscriber to pick the events up. See [Telemetry](../docs/configuration.md#telemetry).
