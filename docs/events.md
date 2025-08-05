# Events

CMDx provides a powerful event system similar to the [stripe_event](https://github.com/integrallis/stripe_event/blob/master/lib/stripe_event.rb) gem, allowing you to subscribe to and react to various events that occur during task execution. This enables building loosely coupled, reactive systems around your command objects.

## Table of Contents

- [TLDR](#tldr)
- [Event Types](#event-types)
- [Subscribing to Events](#subscribing-to-events)
- [Event Data](#event-data)
- [Wildcard Subscriptions](#wildcard-subscriptions)
- [Error Handling](#error-handling)
- [Configuration](#configuration)
- [Testing](#testing)

## TLDR

```ruby
# Subscribe to specific events
CMDx.subscribe("task.success") do |event|
  EmailService.send_notification(event.data[:task])
end

# Subscribe to all task events
CMDx.subscribe("task.*") do |event|
  Analytics.track(event.name, event.data)
end

# Subscribe to all events
CMDx.all do |event|
  Logger.info("Event: #{event.name}")
end

# Subscribe to class-specific events
CMDx.subscribe("user.registration.task.success") do |event|
  WelcomeEmailTask.execute(user_id: event.data[:context].user_id)
end

# Manual event publishing
CMDx.publish("custom.event", { data: "custom data" })
```

> [!IMPORTANT]
> Events are published automatically during task execution and provide rich context about the task, result, and execution state.

## Event Types

The event system publishes several types of events during task execution:

### State Events
| Event | Description | When Published |
|-------|-------------|----------------|
| `task.complete` | Task completed normally | After `call` method completes |
| `task.interrupted` | Task was interrupted | When task is halted by exception |
| `task.executed` | Task finished executing | After any completion state |

### Status Events
| Event | Description | When Published |
|-------|-------------|----------------|
| `task.success` | Task completed successfully | When result status is success |
| `task.skipped` | Task was skipped | When result status is skipped |
| `task.failed` | Task failed | When result status is failed |

### Outcome Events
| Event | Description | When Published |
|-------|-------------|----------------|
| `task.good` | Positive outcome | For success/skipped status |
| `task.bad` | Negative outcome | For failed status |

### General Events
| Event | Description | When Published |
|-------|-------------|----------------|
| `task` | General task event | After every task execution |

### Class-Specific Events
Events are also published with the task's class name (converted to underscore notation):

```ruby
class User::RegistrationTask < CMDx::Task
  # Publishes: user.registration.task.success, user.registration.task, etc.
end
```

## Subscribing to Events

### Block Subscribers

```ruby
CMDx.subscribe("task.success") do |event|
  puts "Task succeeded: #{event.data[:task].class.name}"
end
```

### Callable Objects

```ruby
class TaskLogger
  def call(event)
    Rails.logger.info("Task event: #{event.name}")
  end
end

CMDx.subscribe("task.*", TaskLogger.new)
```

### Proc/Lambda Subscribers

```ruby
success_handler = ->(event) { Metrics.increment("task.success") }
CMDx.subscribe("task.success", success_handler)
```

## Event Data

Every event includes rich contextual data:

```ruby
CMDx.subscribe("task.success") do |event|
  event.name        # => "task.success"
  event.type        # => "task.success" (alias for name)
  event.timestamp   # => Time object when event was published
  event.data        # => Hash with task execution context

  # Access event data
  event.data[:task]      # => The task instance
  event.data[:result]    # => The task result
  event.data[:context]   # => The task context
  event.data[:timestamp] # => When task completed

  # Convenience access
  event["task"]     # => Same as event.data[:task]
end
```

### Example: Logging Task Execution

```ruby
CMDx.subscribe("task.*") do |event|
  task = event.data[:task]
  result = event.data[:result]

  Rails.logger.info(
    "Task: #{task.class.name}, " \
    "Status: #{result.status}, " \
    "Duration: #{result.runtime}ms, " \
    "Event: #{event.name}"
  )
end
```

## Wildcard Subscriptions

### Subscribe to Event Namespaces

```ruby
# All task events
CMDx.subscribe("task.*") do |event|
  # Handles task.success, task.failed, task.complete, etc.
end

# All events for specific task class
CMDx.subscribe("user.registration.*") do |event|
  # Handles user.registration.task.success, user.registration.task.failed, etc.
end
```

### Subscribe to All Events

```ruby
CMDx.all do |event|
  # Receives every event published
  EventStore.append(event.name, event.data)
end

# Alternative syntax
CMDx.subscribe("*") do |event|
  # Same as above
end
```

## Error Handling

Event subscribers are isolated from task execution - subscriber errors won't affect task results:

```ruby
CMDx.subscribe("task.success") do |event|
  raise "Subscriber error"  # Won't break task execution
end

CMDx.subscribe("task.success") do |event|
  puts "This will still execute"  # Continues after previous error
end
```

Subscriber errors are logged but don't propagate:

```ruby
# In your logs you'll see:
# ERROR -- : Event subscriber error: RuntimeError: Subscriber error
```

## Configuration

### Global Event Registry

Events use the global configuration by default:

```ruby
CMDx.configure do |config|
  # Access the event registry
  config.events.subscribe("task.success") { |event| ... }
  config.events.clear  # Remove all subscriptions
end
```

### Custom Event Registry

You can replace the global event registry:

```ruby
CMDx.configure do |config|
  config.events = CMDx::EventRegistry.new
end
```

## Testing

### Testing Event Publications

```ruby
RSpec.describe MyTask do
  let(:events_received) { [] }

  before do
    CMDx.subscribe("task.success") do |event|
      events_received << event
    end
  end

  it "publishes success event" do
    MyTask.execute(param: "value")

    expect(events_received.size).to eq(1)
    expect(events_received.first.name).to eq("task.success")
  end
end
```

### Testing Event Subscribers

```ruby
RSpec.describe "event subscribers" do
  it "processes task success events" do
    expect(EmailService).to receive(:send_notification)

    CMDx.subscribe("task.success") do |event|
      EmailService.send_notification(event.data[:task])
    end

    MyTask.execute(param: "value")
  end
end
```

### Mocking Events

```ruby
# Publish test events manually
CMDx.publish("task.success", {
  task: double("task"),
  result: double("result", status: "success"),
  context: double("context"),
  timestamp: Time.current
})
```

## Real-World Examples

### Analytics Tracking

```ruby
CMDx.subscribe("task.*") do |event|
  task = event.data[:task]
  result = event.data[:result]

  Analytics.track("task_execution", {
    task_class: task.class.name,
    status: result.status,
    duration: result.runtime,
    event_type: event.name
  })
end
```

### Error Monitoring

```ruby
CMDx.subscribe("task.failed") do |event|
  task = event.data[:task]
  result = event.data[:result]

  ErrorTracker.capture_exception(
    result.cause || StandardError.new(result.reason),
    tags: {
      task_class: task.class.name,
      task_id: task.id
    },
    extra: {
      context: event.data[:context].to_h,
      result: result.to_h
    }
  )
end
```

### Workflow Orchestration

```ruby
CMDx.subscribe("user.registration.task.success") do |event|
  context = event.data[:context]

  # Trigger follow-up tasks
  User::SendWelcomeEmailTask.execute(user_id: context.user_id)
  User::CreateProfileTask.execute(user_id: context.user_id)
  Analytics::TrackRegistrationTask.execute(user_id: context.user_id)
end
```

### Caching Invalidation

```ruby
CMDx.subscribe("user.*") do |event|
  if %w[success skipped].include?(event.data[:result].status)
    context = event.data[:context]
    Rails.cache.delete("user:#{context.user_id}") if context.respond_to?(:user_id)
  end
end
```
