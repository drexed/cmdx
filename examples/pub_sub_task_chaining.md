# Pub/Sub Task Chaining

Decouple task sequencing by publishing a notification when one task succeeds and having a subscriber kick off the next.

## Setup

```ruby
# app/tasks/send_welcome_email.rb
class SendWelcomeEmail < CMDx::Task
  required :user_id

  def work
    WelcomeMailer.with(user_id:).deliver_later
  end
end

# config/initializers/cmdx_subscriptions.rb
ActiveSupport::Notifications.subscribe("user.registered") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  SendWelcomeEmail.execute(user_id: event.payload[:user_id])
end
```

## Usage

```ruby
class RegisterUser < CMDx::Task
  required :email, :name

  on_success :publish_registration_event

  def work
    user = User.create!(email:, name:)
    context.user_id = user.id
  end

  private

  def publish_registration_event
    ActiveSupport::Notifications.instrument("user.registered", user_id: context.user_id, email:)
  end
end

RegisterUser.execute(email: "jane@example.com", name: "Jane Doe")
```

## Notes

!!! warning "Important"

    `on_success` fires **after** `work`, so any payload the subscriber needs (`context.user_id` above) must be written to the context inside `work` first.

!!! tip

    For framework-wide observability (not task-to-task chaining), subscribe to CMDx's own `:task_executed` event in [Telemetry](../docs/configuration.md#telemetry) — the subscriber receives the finalized `Result`, no custom instrumentation needed.
