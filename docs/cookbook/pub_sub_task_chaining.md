# Pub/Sub Task Chaining

`RegisterUser` succeeds. Now you need a welcome email, a search index update, and an analytics event. You *could* call three more tasks from inside `work` — but then every change to “what happens after signup” edits the same file.

Publish a domain event when the task succeeds. Subscribers enqueue their own tasks. The registering task stays focused on creating the user.

## Setup — subscriber

Listen for the event and enqueue follow-on work. ActiveSupport::Notifications is built into Rails; swap in Wisper, Kafka, or whatever your app already uses.

```ruby
class SendWelcomeEmail < ApplicationTask
  required :user_id, coerce: :integer

  def work
    WelcomeMailer.with(user_id:).deliver_later
  end
end
```

`ApplicationTask` here is the base class from [Background Execution](background_execution.md) with `execute_later` wired to `TaskJob`.

```ruby
ActiveSupport::Notifications.subscribe("user.registered") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  SendWelcomeEmail.execute_later(user_id: event.payload[:user_id])
end
```

## Usage

Put anything subscribers need on `context` inside `work`, then publish from an `on_success` callback.

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

### Order matters

`on_success` runs after `work` finishes. Subscribers only see what you wrote to `context` during `work` — set `context.user` (or similar) before the callback fires.

### Workflows vs pub/sub

For the **next step in the same process** with shared context, use a [workflow](../workflows.md). Publish events when subscribers should stay decoupled — mailers, analytics, separate queues.
