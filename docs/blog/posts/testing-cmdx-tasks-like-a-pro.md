---
date: 2026-03-11
authors:
  - drexed
categories:
  - Tutorials
slug: testing-cmdx-tasks-like-a-pro
---

# Testing CMDx Tasks Like a Pro

I have a confession: I used to skip tests for service objects. Not because I didn't care, but because testing them was painful. Mock the database, stub the API, wrestle with instance variables, pray the test actually exercises the code path you think it does. The friction was real, and it showed in our coverage numbers.

When I built CMDx, I made a promise to myself—if the framework isn't dead simple to test, it's not done. Every task takes data in and pushes a result out. No hidden state, no side-channel mutations, no surprises. That makes testing almost enjoyable. Almost.

<!-- more -->

## Setting Up Your Test Environment

Before writing any specs, you need a clean slate between tests. CMDx tasks are single-use and chains are thread-local, so resetting between examples prevents state leakage:

```ruby
# spec/rails_helper.rb or spec/spec_helper.rb
RSpec.configure do |config|
  config.before(:each) do
    CMDx.reset_configuration!
    CMDx::Chain.clear
  end
end
```

That's it. Two lines in your setup and you're guaranteed isolation between tests. No elaborate `DatabaseCleaner` strategies for your business logic layer.

## The Basic Pattern

Every CMDx test follows the same shape: execute, then assert on the result. Here's a simple Ruby task and its spec:

```ruby
class CreateUser < CMDx::Task
  required :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  required :name, presence: true

  def work
    context.user = User.create!(email: email, name: name)
  end
end
```

```ruby
RSpec.describe CreateUser do
  it "creates a user successfully" do
    result = CreateUser.execute(email: "ada@example.com", name: "Ada Lovelace")

    expect(result).to be_success
    expect(result.context.user).to be_persisted
    expect(result.context.user.email).to eq("ada@example.com")
  end

  it "fails with invalid email" do
    result = CreateUser.execute(email: "not-an-email", name: "Ada")

    expect(result).to be_failed
    expect(result.metadata[:errors][:messages]).to have_key(:email)
  end
end
```

No mocks. No stubs. Pass data in, check the result. The task's attribute validations run automatically, so you don't need separate tests for "what if email is nil?"—CMDx already handles that, and your test proves it.

## Testing the Three Outcomes

Every task resolves to one of three statuses: `success`, `skipped`, or `failed`. Your tests should cover each path that your task can take.

### Success

```ruby
RSpec.describe ProcessRefund do
  it "processes a pending refund" do
    refund = create(:refund, status: :pending, amount_cents: 5000)

    result = ProcessRefund.execute(refund_id: refund.id)

    expect(result).to be_success
    expect(result.context.refunded_at).to be_present
    expect(refund.reload.status).to eq("completed")
  end
end
```

### Skip

```ruby
RSpec.describe ProcessRefund do
  it "skips when already processed" do
    refund = create(:refund, status: :completed)

    result = ProcessRefund.execute(refund_id: refund.id)

    expect(result).to be_skipped
    expect(result.reason).to eq("Refund already processed")
  end
end
```

### Failure

```ruby
RSpec.describe ProcessRefund do
  it "fails when refund is expired" do
    refund = create(:refund, expired_at: 1.day.ago)

    result = ProcessRefund.execute(refund_id: refund.id)

    expect(result).to be_failed
    expect(result.metadata[:error_code]).to eq("REFUND_EXPIRED")
  end
end
```

Notice how each test reads like a sentence: "it skips when already processed." The result predicates (`be_success`, `be_skipped`, `be_failed`) map directly to what happened. No boolean gymnastics.

## Testing Attribute Validation

One of the best parts of CMDx is that input validation happens *before* your `work` method runs. This means you can test validation in complete isolation from business logic:

```ruby
class CreateProject < CMDx::Task
  required :name, presence: true
  required :budget, type: :integer, numeric: { min: 0 }
  optional :description, length: { max: 500 }

  def work
    context.project = Project.create!(name: name, budget: budget, description: description)
  end
end
```

```ruby
RSpec.describe CreateProject do
  it "fails when required attributes are missing" do
    result = CreateProject.execute(name: nil, budget: 1000)

    expect(result).to be_failed
    expect(result.metadata[:errors][:messages]).to have_key(:name)
  end

  it "coerces string budget to integer" do
    result = CreateProject.execute(name: "Alpha", budget: "5000")

    expect(result).to be_success
    expect(result.context.project.budget).to eq(5000)
  end

  it "fails when budget is negative" do
    result = CreateProject.execute(name: "Alpha", budget: -100)

    expect(result).to be_failed
    expect(result.metadata[:errors][:messages]).to have_key(:budget)
  end
end
```

The coercion test is my favorite. Pass `"5000"` as a string, get `5000` as an integer. CMDx handles the conversion, and your test proves it works end-to-end.

## Testing Bang Execution

When you use `execute!`, failures raise faults instead of returning results. Test these with RSpec's `raise_error` matcher:

```ruby
RSpec.describe ProcessPayment do
  it "raises FailFault on invalid amount" do
    expect {
      ProcessPayment.execute!(amount: -1)
    }.to raise_error(CMDx::FailFault) { |fault|
      expect(fault.result.reason).to include("positive")
    }
  end

  it "raises SkipFault when already charged" do
    payment = create(:payment, status: :charged)

    expect {
      ProcessPayment.execute!(payment_id: payment.id)
    }.to raise_error(CMDx::SkipFault) { |fault|
      expect(fault.result.reason).to include("already")
    }
  end
end
```

The block form of `raise_error` gives you access to the fault object, which carries the full result. You can inspect `reason`, `metadata`, `context`—everything.

## Testing Returns

If your task declares `returns`, CMDx validates that those context keys are set after `work` completes. Test this like any other failure:

```ruby
class AuthenticateUser < CMDx::Task
  required :email, :password

  returns :user, :token

  def work
    context.user = User.authenticate(email, password)
    context.token = JwtService.encode(user_id: context.user.id) if context.user
  end
end
```

```ruby
RSpec.describe AuthenticateUser do
  it "fails when authentication returns nil" do
    result = AuthenticateUser.execute(email: "nobody@example.com", password: "wrong")

    expect(result).to be_failed
    expect(result.metadata[:errors][:messages]).to have_key(:user)
  end

  it "sets all declared returns on success" do
    user = create(:user, password: "secret123")

    result = AuthenticateUser.execute(email: user.email, password: "secret123")

    expect(result).to be_success
    expect(result.context.user).to eq(user)
    expect(result.context.token).to be_present
  end
end
```

## Testing Workflows

Workflows are where testing gets really interesting. You're not just testing one task—you're testing an orchestration. The chain gives you visibility into every step:

```ruby
class OnboardUser < CMDx::Task
  include CMDx::Workflow

  settings workflow_breakpoints: ["failed"]

  task CreateAccount
  task SetupPreferences
  task SendWelcomeEmail
end
```

```ruby
RSpec.describe OnboardUser do
  it "runs all tasks in sequence" do
    result = OnboardUser.execute(
      email: "ada@example.com",
      name: "Ada",
      preferences: { theme: "dark" }
    )

    expect(result).to be_success
    expect(result.chain.results.size).to eq(4) # workflow + 3 tasks
    expect(result.chain.results.map { |r| r.task.class }).to eq(
      [OnboardUser, CreateAccount, SetupPreferences, SendWelcomeEmail]
    )
  end

  it "stops on first failure and traces the cause" do
    result = OnboardUser.execute(email: nil, name: "Ada")

    expect(result).to be_failed
    expect(result.caused_failure.task).to be_a(CreateAccount)
    expect(result.caused_failure.reason).to include("email")
  end
end
```

The `caused_failure` accessor is gold for workflow tests. When a pipeline fails, you know exactly which step broke and why—no digging through logs.

## Testing Callbacks

Callbacks are side effects, so test that they fire without testing their internal implementation:

```ruby
class ProcessBooking < CMDx::Task
  on_success :notify_guest
  on_failed :alert_support

  required :booking_id

  def work
    booking = Booking.find(booking_id)
    booking.confirm!
    context.booking = booking
  end

  private

  def notify_guest
    BookingMailer.confirmation(context.booking).deliver_later
  end

  def alert_support
    SupportAlerts.booking_failed(booking_id: booking_id, reason: result.reason)
  end
end
```

```ruby
RSpec.describe ProcessBooking do
  it "sends confirmation on success" do
    booking = create(:booking)
    allow(BookingMailer).to receive_message_chain(:confirmation, :deliver_later)

    ProcessBooking.execute(booking_id: booking.id)

    expect(BookingMailer).to have_received(:confirmation)
  end

  it "alerts support on failure" do
    allow(SupportAlerts).to receive(:booking_failed)

    ProcessBooking.execute(booking_id: -1)

    expect(SupportAlerts).to have_received(:booking_failed)
  end
end
```

## Testing Dry Run

Dry run mode is perfect for preview features. Verify that it simulates without side effects:

```ruby
RSpec.describe CancelSubscription do
  it "simulates without actually cancelling" do
    subscription = create(:subscription, status: :active)

    result = CancelSubscription.execute(subscription_id: subscription.id, dry_run: true)

    expect(result).to be_success
    expect(result.dry_run?).to be(true)
    expect(subscription.reload.status).to eq("active") # unchanged
    expect(result.context.refund_amount).to be_present
  end
end
```

## Direct Instantiation for Fine-Grained Inspection

Sometimes you want to inspect the task *before* execution—check that context was initialized correctly, or verify attribute accessors:

```ruby
RSpec.describe CalculateShipping do
  it "exposes context before execution" do
    task = CalculateShipping.new(weight: 2.5, destination: "CA")

    expect(task.context.weight).to eq(2.5)
    expect(task.result).to be_initialized
  end

  it "freezes after execution" do
    task = CalculateShipping.new(weight: 2.5, destination: "CA")
    task.execute

    expect(task.result).to be_success
    expect(task).to be_frozen
  end
end
```

## Pattern Matching in Tests

Ruby's pattern matching pairs beautifully with CMDx results for expressive assertions:

```ruby
RSpec.describe BuildApplication do
  it "matches expected pattern on failure" do
    result = BuildApplication.execute(version: nil)

    case result
    in { status: "failed", metadata: { errors: { messages: Hash => msgs } } }
      expect(msgs).to have_key(:version)
    else
      raise "Expected failed result with validation errors"
    end
  end
end
```

This is especially powerful for testing complex metadata structures without deeply nested `expect` chains.

## Key Takeaways

1. **Reset between tests** — `CMDx.reset_configuration!` and `CMDx::Chain.clear` in your `before(:each)`.

2. **Test outcomes, not internals** — Execute and assert on the result. The task is a black box with a well-defined contract.

3. **Cover all three paths** — Success, skip, and failure. Each tells a different story.

4. **Use the chain for workflow assertions** — `caused_failure` traces exactly which step broke.

5. **Prefer real objects** — CMDx's design makes mocking largely unnecessary. Pass real data, get real results.

Testing shouldn't be the thing you dread. With CMDx, it's just another conversation between your data and your assertions.

Happy testing!

## References

- [Testing](https://drexed.github.io/cmdx/testing/)
- [Execution](https://drexed.github.io/cmdx/basics/execution/)
- [Returns](https://drexed.github.io/cmdx/returns/)
