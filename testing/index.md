# Testing

Hey — if you can read RSpec, you can test CMDx. This page is a cheat sheet for checking that your tasks and workflows do what you expect.

## Testing Tasks

### Basic execution

Call `execute` on your task. You get back a `Result` object. Treat it like a little report card: `success?`, `skipped?`, and `failed?` tell you how it went, and RSpec matchers understand them out of the box.

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

When one example needs to branch on the outcome, `Result#on` keeps each branch tidy — no giant `if` soup.

```ruby
it "branches on outcome" do
  CreateUser.execute(email: "dev@example.com", name: "Ada")
    .on(:success) { |r| expect(r.context.user).to be_persisted }
    .on(:failed)  { |r| raise "unexpected failure: #{r.reason}" }
end
```

### Testing skip and fail

When your task calls `skip!` or `fail!`, whatever you pass in shows up on the result as `reason` and `metadata`. Assert those like any other value.

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

### Testing bang execution (`execute!`)

`execute!` is the loud version: if anything goes wrong (validation, bad outputs, `fail!`, or a bubbled-up failure from another task), it raises `CMDx::Fault`. That exception carries which task blew up and the `Result` that explains why.

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

If your task re-raises the *original* exception (say, a bare `JSON::ParserError` from `work`), expect that class — not `Fault`.

```ruby
expect { Importer.execute!(payload: bad_payload) }.to raise_error(JSON::ParserError)
```

Note

Peek at `fault.result`, `fault.context`, and `fault.chain` when you need a full post-mortem. When you care about **all** three outcomes — success, skip, *and* failure — in one example, stick with quiet `execute` instead of `execute!`.

### Testing input validation

Bad inputs land in `result.errors`. The human-readable summary is usually in `result.reason` too.

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

Note

After coercion, the *nice* typed values often live on the task instance (the reader CMDx generates), not on `context`. `result.context` still reflects what the caller passed unless **you** copy coerced values onto `context` inside `work` (for example `context.budget = budget`).

### Testing outputs

If you declared an `output` and it is missing or invalid, the task fails — same `errors` API as inputs.

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

### Testing retries

Retries are boring to watch in real life; in tests they are easy. `result.retries` counts attempts beyond the first, and `result.retried?` is just `retries > 0`.

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

## Testing workflows

### Sequential workflow

A workflow's `chain` is the story of everything that ran, in order. The root entry is the workflow itself.

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

### Failure propagation

First failure wins: the pipeline stops, and the workflow's `reason` echoes the unhappy task. You do not have to hunt through the chain — `result.origin` and `result.caused_failure` point at the task that started the trouble.

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

Note

`caused_failure` digs to the deepest failing leaf, even inside nested workflows. `threw_failure` is the immediate upstream (`origin` or the result itself). When the failing task *is* the leaf you are looking at, both helpers return `self`. More detail: [Result — Chain Analysis](https://drexed.github.io/cmdx/outcomes/result/#chain-analysis).

## Testing callbacks

Callbacks are easiest to trust when you watch something happen — mailers sent, flags flipped, jobs enqueued. Stub or spy on the collaborator and assert it was called.

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

## Testing middlewares

Middleware wraps the real task lifecycle, so the friendliest test is a tiny task that exercises your middleware end-to-end. See [Middlewares](https://drexed.github.io/cmdx/middlewares/index.md) for the big picture.

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

## Direct instantiation

Sometimes you want to peek before you run. `Task.new(...)` builds the context and error bucket but **does not** execute anything. Handy for cheap sanity checks.

```ruby
RSpec.describe CalculateShipping do
  it "exposes context before execution" do
    task = CalculateShipping.new(weight: 2.5, destination: "CA")

    expect(task.context.weight).to eq(2.5)
    expect(task.errors).to be_empty
  end
end
```

Note

There is no `task.execute` on the instance. To actually run the lifecycle, call `YourTask.execute(...)` (with a hash or a context). `new` is setup only.

## Pattern matching in tests

Feeling fancy? `Result` supports Ruby pattern matching — both array-style and hash-style.

```ruby
RSpec.describe BuildApplication do
  it "deconstructs to [[key, value], ...] pairs" do
    result = BuildApplication.execute(version: "1.0")

    expect(result.deconstruct).to include(
      [:type, "Task"],
      [:task, BuildApplication],
      [:state, "complete"],
      [:status, "success"]
    )

    case result
    in [*, [:status, "success"], *] then :ok
    end
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

Note

`Result#deconstruct` is `to_h.to_a` — a list of `[key, value]` pairs in hash insertion order, not a fixed-size tuple. Prefer "find" patterns like `in [*, [:status, "success"], *]` instead of counting positions by hand.
