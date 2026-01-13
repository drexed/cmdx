---
date: 2026-03-11
authors:
  - drexed
categories:
  - Tutorials
slug: running-cmdx-tasks-asynchronously-with-sidekiq
---

# Running CMDx Tasks Asynchronously with Sidekiq

Some operations just don't belong in a web request. Sending emails, processing uploads, syncing with third-party APIs—these can take seconds or even minutes. Making your users stare at a spinner while you crunch numbers is a recipe for frustration and timeouts.

That's where background jobs come in. And in the Ruby world, Sidekiq is the gold standard. What if you could take your clean, observable CMDx tasks and run them asynchronously without creating a separate job class for each one? That's exactly what we're going to build today.

<!-- more -->

## The Traditional Approach (And Its Problems)

In a typical Rails application, you'd create a job class that calls your service:

```ruby
class ProcessInvoiceJob < ApplicationJob
  def perform(invoice_id)
    ProcessInvoice.execute(invoice_id: invoice_id)
  end
end
```

This works, but it introduces friction:

- **Boilerplate**: Every task needs a matching job class
- **Scattered logic**: Business logic lives in one place, scheduling in another
- **Inconsistent patterns**: Some teams put logic in jobs, some in services—chaos ensues

What if the task *itself* could be the job?

## Making CMDx Tasks Sidekiq-Native

The integration is surprisingly simple. By including `Sidekiq::Job` in your task and implementing `perform`, you get the best of both worlds: CMDx's clean execution model and Sidekiq's robust background processing.

```ruby
class SendWelcomeEmail < CMDx::Task
  include Sidekiq::Job

  required :user_id, type: :integer

  def work
    user = User.find(user_id)
    UserMailer.welcome(user).deliver_now
    context.sent_at = Time.current
  end

  def perform(user_id)
    self.class.execute!(user_id: user_id)
  end
end
```

Now you have two ways to run this task:

```ruby
# Synchronously (in the request cycle)
SendWelcomeEmail.execute(user_id: 42)

# Asynchronously (in the background)
SendWelcomeEmail.perform_async(42)
```

Same class. Same business logic. Same observability. Different execution context.

## Why execute! Instead of execute?

Notice that I'm using `execute!` (with the bang) inside `perform`. This is deliberate.

Sidekiq has its own retry mechanism. When a job raises an exception, Sidekiq catches it, logs it, and schedules a retry based on your configuration. If we used `execute` (without the bang), failures would be silently captured in the result object—Sidekiq would think the job succeeded.

By using `execute!`, we let CMDx failures bubble up as `CMDx::FailFault` exceptions. Sidekiq sees the exception, marks the job as failed, and handles the retry. Your task's retry settings and Sidekiq's retry settings can work together.

```ruby
class ChargeSubscription < CMDx::Task
  include Sidekiq::Job

  # Sidekiq options
  sidekiq_options retry: 5, queue: :billing

  required :subscription_id, type: :integer

  def work
    subscription = Subscription.find(subscription_id)

    if subscription.payment_method.expired?
      fail!("Payment method expired", code: :expired_payment)
    end

    charge = Stripe::Charge.create(
      amount: subscription.amount_cents,
      customer: subscription.user.stripe_customer_id
    )

    context.charge_id = charge.id
  end

  def perform(subscription_id)
    self.class.execute!(subscription_id: subscription_id)
  end
end
```

When the task calls `fail!`, it raises `CMDx::FailFault`. Sidekiq catches it, and the job enters the retry queue. After 5 retries (per our `sidekiq_options`), it moves to the dead set for manual review.

## Passing Complex Arguments

Sidekiq serializes job arguments to JSON, so you're limited to simple types: strings, numbers, booleans, arrays, and hashes. This is actually a good constraint—it forces you to pass IDs instead of full objects.

```ruby
class ProcessOrder < CMDx::Task
  include Sidekiq::Job

  sidekiq_options queue: :orders

  required :order_id, type: :integer
  optional :notify_customer, type: :boolean, default: true

  def work
    order = Order.find(order_id)
    order.process!

    if notify_customer
      OrderMailer.confirmation(order).deliver_later
    end

    context.processed_at = Time.current
  end

  def perform(order_id, notify_customer = true)
    self.class.execute!(
      order_id: order_id,
      notify_customer: notify_customer
    )
  end
end

# Queue it up
ProcessOrder.perform_async(123, false)
```

## Scheduling Jobs for Later

Sidekiq's scheduling features work seamlessly:

```ruby
# Process in 10 minutes
ProcessOrder.perform_in(10.minutes, order_id)

# Process at a specific time
ProcessOrder.perform_at(Time.current + 1.hour, order_id)
```

This is perfect for scenarios like:

- Delayed notifications ("Your trial expires tomorrow")
- Rate-limited API calls
- Business-hour processing

## Real-World Example: Image Processing Pipeline

Let me show you a more complete example. Imagine users upload images that need resizing, optimization, and CDN upload:

```ruby
class ProcessUserAvatar < CMDx::Task
  include Sidekiq::Job

  sidekiq_options queue: :media, retry: 3

  required :user_id, type: :integer
  required :blob_id, type: :integer

  def work
    user = User.find(user_id)
    blob = ActiveStorage::Blob.find(blob_id)

    # Download and process
    blob.open do |file|
      processed = ImageProcessor.resize(file, 256, 256)
      optimized = ImageProcessor.optimize(processed)

      # Upload to CDN
      cdn_url = CdnUploader.upload(optimized, path: "avatars/#{user.id}")
      user.update!(avatar_url: cdn_url)

      context.cdn_url = cdn_url
    end

    logger.info "Avatar processed for user #{user_id}"
  end

  def perform(user_id, blob_id)
    self.class.execute!(user_id: user_id, blob_id: blob_id)
  end
end
```

In your controller:

```ruby
class AvatarsController < ApplicationController
  def create
    blob = ActiveStorage::Blob.create_and_upload!(
      io: params[:avatar],
      filename: params[:avatar].original_filename
    )

    # Don't make the user wait for processing
    ProcessUserAvatar.perform_async(current_user.id, blob.id)

    render json: { status: "processing" }, status: :accepted
  end
end
```

The upload completes instantly. The heavy lifting happens in the background. The user gets a snappy experience.

## Combining with CMDx Callbacks

CMDx callbacks still work in async execution:

```ruby
class GenerateReport < CMDx::Task
  include Sidekiq::Job

  sidekiq_options queue: :reports

  on_success :notify_requester
  on_failed :alert_admin

  required :report_type, type: :symbol
  required :requester_id, type: :integer

  def work
    data = ReportGenerator.generate(report_type)
    context.report_url = ReportStorage.store(data)
  end

  def perform(report_type, requester_id)
    self.class.execute!(
      report_type: report_type.to_sym,
      requester_id: requester_id
    )
  end

  private

  def notify_requester
    user = User.find(requester_id)
    ReportMailer.ready(user, context.report_url).deliver_later
  end

  def alert_admin
    AdminNotifier.report_failed(
      report_type: report_type,
      reason: result.reason
    )
  end
end
```

When the job succeeds, `notify_requester` fires. When it fails (even after Sidekiq retries exhaust), `alert_admin` gets called on that final attempt.

## Monitoring and Observability

One of my favorite aspects of this pattern is that CMDx's logging still works:

```json
{"index":0,"chain_id":"abc123","class":"ProcessUserAvatar","state":"complete","status":"success","metadata":{"runtime":2341}}
```

That log entry appears in your Sidekiq worker's output. Combined with Sidekiq's built-in job logging, you get complete visibility into what happened—and when.

For production systems, I recommend adding the correlation middleware:

```ruby
class ProcessUserAvatar < CMDx::Task
  include Sidekiq::Job

  register :middleware, CMDx::Middlewares::Correlate
  register :middleware, CMDx::Middlewares::Runtime

  # ... rest of task
end
```

Now every log entry includes a correlation ID and precise timing. When debugging a failed job, you can trace the entire execution path.

## Testing Async Tasks

Testing these hybrid tasks is straightforward. For unit tests, execute synchronously:

```ruby
RSpec.describe ProcessUserAvatar do
  it "processes and uploads the avatar" do
    user = create(:user)
    blob = create(:blob, :image)

    result = described_class.execute(user_id: user.id, blob_id: blob.id)

    expect(result).to be_success
    expect(result.context.cdn_url).to be_present
    expect(user.reload.avatar_url).to eq(result.context.cdn_url)
  end
end
```

For integration tests with Sidekiq, use `Sidekiq::Testing`:

```ruby
RSpec.describe "Avatar upload flow", type: :request do
  around do |example|
    Sidekiq::Testing.inline! { example.run }
  end

  it "processes avatar asynchronously" do
    user = create(:user)
    file = fixture_file_upload("avatar.jpg")

    post avatars_path, params: { avatar: file }

    expect(response).to have_http_status(:accepted)
    expect(user.reload.avatar_url).to be_present
  end
end
```

## When to Use This Pattern

This CMDx + Sidekiq integration shines when:

- **Operations are slow**: API calls, file processing, heavy computations
- **Failures are recoverable**: Network timeouts, rate limits, temporary outages
- **Users don't need immediate results**: Emails, reports, data syncs
- **You want unified business logic**: Same task class for sync and async execution

It's probably overkill for simple, fast operations. A quick database write doesn't need background processing.

## Wrapping Up

By combining CMDx's structured task pattern with Sidekiq's battle-tested background processing, you get a powerful foundation for async operations. Your business logic stays clean and testable. Your users get snappy responses. Your ops team gets observable, retryable jobs.

The pattern is simple: include `Sidekiq::Job`, implement `perform`, call `execute!`. Everything else—attributes, callbacks, logging, middlewares—just works.

Give it a try on your next feature. Start with something simple like email sending, then expand to more complex pipelines. You'll wonder how you ever managed without it.

Happy coding!
