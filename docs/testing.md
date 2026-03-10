# Testing

Best practices for testing CMDx tasks and workflows with RSpec.

## Setup

Reset global configuration between tests to prevent state leakage:

```ruby
# spec/rails_helper.rb or spec/spec_helper.rb
RSpec.configure do |config|
  config.before(:each) do
    CMDx.reset_configuration!
    CMDx::Chain.clear
  end
end
```

## Testing Tasks

### Basic Execution

Test tasks by calling `execute` and asserting on the result:

```ruby
RSpec.describe CreateUser do
  it "creates a user successfully" do
    result = CreateUser.execute(email: "dev@example.com", name: "Ada")

    expect(result).to be_success
    expect(result.context.user).to be_persisted
    expect(result.context.user.email).to eq("dev@example.com")
  end

  it "fails with invalid email" do
    result = CreateUser.execute(email: "", name: "Ada")

    expect(result).to be_failed
    expect(result.reason).to include("Invalid")
  end
end
```

### Testing Skip and Fail Conditions

```ruby
RSpec.describe ProcessRefund do
  it "skips when refund is already processed" do
    refund = create(:refund, status: :completed)

    result = ProcessRefund.execute(refund_id: refund.id)

    expect(result).to be_skipped
    expect(result.reason).to eq("Refund already processed")
  end

  it "fails when refund is expired" do
    refund = create(:refund, expired_at: 1.day.ago)

    result = ProcessRefund.execute(refund_id: refund.id)

    expect(result).to be_failed
    expect(result.metadata[:error_code]).to eq("REFUND_EXPIRED")
  end
end
```

### Testing Bang Execution

```ruby
RSpec.describe ProcessPayment do
  it "raises FailFault on failure" do
    expect {
      ProcessPayment.execute!(amount: -1)
    }.to raise_error(CMDx::FailFault) { |fault|
      expect(fault.result.reason).to include("positive")
    }
  end
end
```

### Testing Attribute Validation

```ruby
RSpec.describe CreateProject do
  it "fails when required attributes are missing" do
    result = CreateProject.execute(name: nil)

    expect(result).to be_failed
    expect(result.reason).to eq("Invalid")
    expect(result.metadata[:errors][:messages]).to have_key(:name)
  end

  it "coerces string attributes to expected types" do
    result = CreateProject.execute(name: "Alpha", budget: "5000")

    expect(result).to be_success
    expect(result.context.budget).to eq(5000)
  end
end
```

### Testing Returns

```ruby
RSpec.describe AuthenticateUser do
  it "fails when declared returns are missing" do
    allow(User).to receive(:authenticate).and_return(nil)

    result = AuthenticateUser.execute(email: "a@b.com", password: "pw")

    expect(result).to be_failed
    expect(result.metadata[:errors][:messages]).to have_key(:token)
  end
end
```

### Testing Dry Run

```ruby
RSpec.describe ChargeCard do
  it "simulates execution without side effects" do
    result = ChargeCard.execute(card_id: "card_123", dry_run: true)

    expect(result).to be_success
    expect(result.dry_run?).to be(true)
  end
end
```

## Testing Workflows

### Full Workflow

```ruby
RSpec.describe OnboardingWorkflow do
  it "runs all tasks in sequence" do
    result = OnboardingWorkflow.execute(user_data: valid_params)

    expect(result).to be_success
    expect(result.chain.results.size).to eq(4)
    expect(result.chain.results.map { |r| r.task.class }).to eq(
      [OnboardingWorkflow, CreateProfile, SetupPreferences, SendWelcome]
    )
  end
end
```

### Workflow Failure Propagation

```ruby
RSpec.describe PaymentWorkflow do
  it "stops on first failure and includes root cause" do
    result = PaymentWorkflow.execute(invalid_card: true)

    expect(result).to be_failed
    expect(result.caused_failure.task).to be_a(ValidateCard)
  end
end
```

## Testing Callbacks

```ruby
RSpec.describe ProcessBooking do
  it "notifies guest on success" do
    allow(GuestNotifier).to receive(:call)
    booking = create(:booking)

    ProcessBooking.execute(booking_id: booking.id)

    expect(GuestNotifier).to have_received(:call)
  end
end
```

## Testing Middlewares

```ruby
RSpec.describe "Timeout middleware" do
  it "fails when task exceeds time limit" do
    result = SlowTask.execute

    expect(result).to be_failed
    expect(result.cause).to be_a(CMDx::TimeoutError)
    expect(result.metadata[:limit]).to eq(3)
  end
end
```

## Direct Instantiation

For fine-grained inspection, instantiate tasks directly:

```ruby
RSpec.describe CalculateShipping do
  it "exposes context before execution" do
    task = CalculateShipping.new(weight: 2.5, destination: "CA")

    expect(task.context.weight).to eq(2.5)
    expect(task.result).to be_initialized
  end

  it "can be executed manually" do
    task = CalculateShipping.new(weight: 2.5, destination: "CA")
    task.execute

    expect(task.result).to be_success
  end
end
```

## Pattern Matching in Tests

Use Ruby's pattern matching for expressive assertions:

```ruby
RSpec.describe BuildApplication do
  it "returns expected pattern on success" do
    result = BuildApplication.execute(version: "1.0")

    expect(result.deconstruct).to match(["complete", "success", anything, anything, anything])
  end

  it "matches hash pattern on failure" do
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
