# ActiveSupport Instrumentation

Emit an `ActiveSupport::Notifications` event for every task execution so subscribers (log sinks, APM, StatsD shippers) can time and tag them.

## Setup

```ruby
# app/middlewares/cmdx_instrumentation_middleware.rb
class CmdxInstrumentationMiddleware
  def call(task)
    ActiveSupport::Notifications.instrument(
      "execute.cmdx",
      task: task.class.name,
      tid:  task.tid,
      cid:  CMDx::Chain.current.id
    ) { yield }
  end
end
```

## Usage

```ruby
class Users::Create < CMDx::Task
  register :middleware, CmdxInstrumentationMiddleware.new

  required :email

  def work
    # ...
  end
end

# config/initializers/cmdx_instrumentation.rb
ActiveSupport::Notifications.subscribe("execute.cmdx") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  Rails.logger.info(
    "#{event.payload[:task]} (#{event.payload[:tid]}) took #{event.duration.round(2)}ms"
  )
end
```

## Notes

!!! tip

    CMDx ships its own pub/sub with `result.duration`, `result.status`, and `result.retries` baked in — subscribe to `:task_executed` in [Telemetry](../docs/configuration.md#telemetry) when you don't need `ActiveSupport::Notifications`' wider ecosystem.
