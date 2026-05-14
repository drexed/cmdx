# Pub/Sub Task Chaining

A task that succeeds often needs to trigger downstream work — a welcome email, a search index refresh, an analytics event. Hard-coding the next call inside `work` couples them at the source. Publishing an event after success and letting subscribers fan out keeps the producing task focused on its own outcome.

## Setup

```ruby
# app/tasks/send_welcome_email.rb
# frozen_string_literal: true

class SendWelcomeEmail < CMDx::Task
  required :user_id, coerce: :integer

  def work
    WelcomeMailer.with(user_id:).deliver_later
  end
end
```

```ruby
# config/initializers/cmdx_subscriptions.rb
# frozen_string_literal: true

ActiveSupport::Notifications.subscribe("user.registered") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  SendWelcomeEmail.perform_later(user_id: event.payload[:user_id])
end
```

## Usage

```ruby
class RegisterUser < CMDx::Task
  required :email, coerce: :string, validate: { format: URI::MailTo::EMAIL_REGEXP }
  required :name,  coerce: :string

  on_success :publish_registration_event

  def work
    context.user = User.create!(email:, name:)
  end

  private

  def publish_registration_event
    ActiveSupport::Notifications.instrument(
      "user.registered",
      user_id: context.user.id,
      email:   context.user.email
    )
  end
end

RegisterUser.execute(email: "jane@example.com", name: "Jane Doe")
```

## Notes

!!! warning "Order matters"

    `on_success` fires after `work` completes. Any data the subscriber needs (`context.user` above) must be written to the context inside `work` first — the callback only sees the post-`work` state.

!!! tip "Lifecycle vs domain events"

    `:task_executed` (CMDx telemetry) is the right channel for *observability* — every task fires it, the subscriber receives a finalized `Result`. `ActiveSupport::Notifications` is the right channel for *domain events* the rest of the app cares about — fire those explicitly from a callback so the domain semantics stay readable.
