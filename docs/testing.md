# Testing

Patterns for testing CMDx tasks and workflows with RSpec.

## Testing Tasks

### Basic Execution

Call `execute` and assert on the returned `Result`. Predicates like `success?`, `skipped?`, and `failed?` map to RSpec matchers automatically.

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
    expect(result.reason).to eq("email cannot be empty")
    expect(result.errors.to_h).to eq(email: ["cannot be empty"])
  end
end
```

For multi-branch assertions, `Result#on` keeps each path scoped:

```ruby
it "branches on outcome" do
  CreateUser.execute(email: "dev@example.com", name: "Ada")
    .on(:success) { |r| expect(r.context.user).to be_persisted }
    .on(:failed)  { |r| raise "unexpected failure: #{r.reason}" }
end
```

### Testing Skip and Fail

`reason` and `metadata` come straight from the `skip!` / `fail!` arguments.

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

`execute!` raises `CMDx::Fault` for any failed path (validation, output verification, `fail!`, or echoed peer failure). The fault carries the failing task class and the originating `Result`.

```ruby
RSpec.describe ProcessPayment do
  it "raises Fault on failure" do
    expect {
      ProcessPayment.execute!(amount: -1)
    }.to raise_error(CMDx::Fault) { |fault|
      expect(fault.task).to eq(ProcessPayment)
      expect(fault.message).to include("amount")
      expect(fault.result.errors).to have_key(:amount)
    }
  end
end
```

For paths that re-raise the original exception (an unhandled `StandardError` inside `work`), match the original class instead:

```ruby
expect { Importer.execute!(payload: bad_payload) }.to raise_error(JSON::ParserError)
```

!!! note

    `Fault` exposes the originating `Result` (`fault.result`), `context`, and
    `chain` so post-mortem inspection works either way. `execute` is still
    handy when you want to assert on `skipped?`, `success?`, *and* `failed?`
    results in the same example.

### Testing Input Validation

Errors from input resolution are surfaced through `result.errors` and folded into `result.reason`.

```ruby
RSpec.describe CreateProject do
  it "fails when required inputs are missing" do
    result = CreateProject.execute(name: nil)

    expect(result).to be_failed
    expect(result.errors.to_h).to have_key(:name)
    expect(result.reason).to include("name")
  end
end
```

!!! note

    Coerced input values live on the task instance (via the generated reader),
    not on `context`. `result.context.budget` returns whatever the caller
    passed in — to assert on the coerced value, write it back to `context`
    inside `work` (e.g. `context.budget = budget`).

### Testing Outputs

Missing or invalid declared outputs fail the task with the same `errors` API.

```ruby
RSpec.describe AuthenticateUser do
  it "fails when a declared output is missing" do
    allow(JwtService).to receive(:encode).and_return(nil)

    result = AuthenticateUser.execute(email: "a@b.com", password: "pw")

    expect(result).to be_failed
    expect(result.errors.to_h).to have_key(:token)
  end
end
```

### Testing Retries

`result.retries` and `result.retried?` expose retry activity.

```ruby
RSpec.describe FetchExternalData do
  it "retries transient timeouts" do
    call_count = 0
    allow(HTTParty).to receive(:get) do
      call_count += 1
      raise Net::ReadTimeout if call_count < 3
      double(parsed_response: { ok: true })
    end

    result = FetchExternalData.execute

    expect(result).to be_success
    expect(result.retries).to eq(2)
    expect(result.retried?).to be(true)
  end
end
```

## Testing Workflows

### Sequential Workflow

The chain holds every result in execution order, with the workflow result as the root.

```ruby
RSpec.describe OnboardingWorkflow do
  it "runs all tasks in sequence" do
    result = OnboardingWorkflow.execute(user_data: valid_params)

    expect(result).to be_success
    expect(result.chain.size).to eq(4)
    expect(result.chain.results.map(&:task)).to eq(
      [OnboardingWorkflow, CreateProfile, SetupPreferences, SendWelcome]
    )
  end
end
```

### Failure Propagation

A failed leaf halts the workflow and its `reason` echoes onto `result.reason`. The failing leaf is reachable directly via `result.origin` / `result.caused_failure` — they point at the originating task without needing to scan the chain.

```ruby
RSpec.describe PaymentWorkflow do
  it "stops on first failure and identifies the failing task" do
    result = PaymentWorkflow.execute(invalid_card: true)

    expect(result).to be_failed
    expect(result.reason).to include("invalid")
    expect(result.origin.task).to eq(ValidateCard)
    expect(result.caused_failure.task).to eq(ValidateCard)
  end
end
```

!!! note

    `caused_failure` walks `origin` recursively, so it returns the deepest
    leaf even across nested workflows. `threw_failure` returns the immediate
    upstream (`origin || self`). For a locally-failing task both helpers
    return `self`. See [Result — Chain Analysis](outcomes/result.md#chain-analysis).

## Testing Callbacks

Callbacks are best verified through their observable side effects.

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

Middlewares run inside Runtime, so test them through a real task lifecycle (see [Middlewares](middlewares.md)).

```ruby
class TaggingMiddleware
  def call(task)
    task.context.tagged_at = Time.now
    yield
  end
end

RSpec.describe TaggingMiddleware do
  it "tags the context before work runs" do
    klass = Class.new(CMDx::Task) do
      register :middleware, TaggingMiddleware.new
      def work; context.work_seen_tag = !context.tagged_at.nil?; end
    end

    result = klass.execute

    expect(result.context.work_seen_tag).to be(true)
  end
end
```

## Direct Instantiation

Instantiate a task directly when you need to inspect its `context` or `errors` before invoking the runtime.

```ruby
RSpec.describe CalculateShipping do
  it "exposes context before execution" do
    task = CalculateShipping.new(weight: 2.5, destination: "CA")

    expect(task.context.weight).to eq(2.5)
    expect(task.errors).to be_empty
  end
end
```

!!! note

    `Task#new` only builds the context and errors registry — it does **not** run the lifecycle. To execute, use `Klass.execute(context_or_hash)`. There is no per-instance `task.execute`.

## Pattern Matching in Tests

`Result` supports both array and hash deconstruction.

```ruby
RSpec.describe BuildApplication do
  it "deconstructs to [type, task, state, status, reason, metadata, cause, origin]" do
    result = BuildApplication.execute(version: "1.0")

    expect(result.deconstruct).to match(
      ["Task", BuildApplication, "complete", "success", nil, {}, nil, nil]
    )
  end

  it "matches a hash pattern on failure" do
    result = BuildApplication.execute(version: nil)

    case result
    in { status: "failed", reason: String => reason }
      expect(reason).to include("version")
    else
      raise "Expected failed result"
    end
  end
end
```
