# Pub/Sub Task Chaining

Decouple task execution using a Pub/Sub mechanism (like `ActiveSupport::Notifications`) where one task's success triggers another.

### Setup

Define the consumer task and the subscriber that listens for the event.

```ruby
# app/tasks/send_welcome_email.rb
class SendWelcomeEmail < CMDx::Task
  required :user_id

  def work
    # In a real app, this might be an API call to an email provider
    puts "📧 Sending welcome email to User ##{user_id}..."
  end
end

# config/initializers/cmdx_subscriptions.rb
ActiveSupport::Notifications.subscribe("user.registered") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)

  # Kick off the second task
  SendWelcomeEmail.call(user_id: event.payload[:user_id])
end
```

### Usage

Define the publisher task that emits the event upon success.

```ruby
class RegisterUser < CMDx::Task
  required :email
  required :name

  # Publish the event only if the task succeeds
  on_success :publish_registration_event

  def work
    # Simulate user creation logic
    context.user_id = rand(1000..9999)
    puts "✅ User '#{name}' registered with ID #{context.user_id}"
  end

  private

  def publish_registration_event
    ActiveSupport::Notifications.instrument(
      "user.registered",
      user_id: context.user_id,
      email: email
    )
  end
end

# Execute the first task
RegisterUser.call(email: "jane@example.com", name: "Jane Doe")
```
