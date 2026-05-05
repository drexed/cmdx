# Testing Reference

Docs: [docs/testing.md](../../docs/testing.md).

CMDx has no custom RSpec helpers — the public API is the test API. `execute` returns a `Result`, `execute!` raises `Fault` (or the original `StandardError`), and every predicate (`success?`, `failed?`, etc.) is automatically exposed as an RSpec matcher (`be_success`, `be_failed`, ...).

## Basic assertions

```ruby
RSpec.describe CreateUser do
  it "succeeds" do
    result = CreateUser.execute(email: "dev@example.com", name: "Ada")

    expect(result).to be_success
    expect(result.context.user).to be_persisted
  end

  it "fails when email is blank" do
    result = CreateUser.execute(email: "", name: "Ada")

    expect(result).to be_failed
    expect(result.reason).to include("email")
    expect(result.errors.to_h).to eq(email: ["cannot be empty"])
  end
end
```

Auto-generated predicate matchers: `be_complete`, `be_interrupted`, `be_success`, `be_skipped`, `be_failed`, `be_ok`, `be_ko`, `be_retried`, `be_rolled_back`, `be_strict`, `be_deprecated`, `be_root`.

## Branching with `on`

```ruby
it "branches cleanly" do
  CreateUser.execute(email: "x@y.com")
    .on(:success) { |r| expect(r.context.user).to be_persisted }
    .on(:failed)  { |r| raise "unexpected: #{r.reason}" }
end
```

## Skip / fail payloads

`reason` and `metadata` come straight from the halting call's arguments.

```ruby
it "skips when already processed" do
  result = ProcessRefund.execute(refund_id: completed.id)

  expect(result).to be_skipped
  expect(result.reason).to eq("Refund already processed")
end

it "fails with metadata" do
  result = ProcessRefund.execute(refund_id: expired.id)

  expect(result).to be_failed
  expect(result.metadata[:error_code]).to eq("REFUND_EXPIRED")
end
```

## `execute!` and `Fault`

`execute!` raises `CMDx::Fault` for every failed path (`fail!`, input/output validation, echoed failures). It does **not** raise on skipped results. If `result.cause` is a non-`Fault` `StandardError`, the original exception is re-raised instead.

```ruby
it "raises Fault on failure" do
  expect {
    ProcessPayment.execute!(amount: -1)
  }.to raise_error(CMDx::Fault) { |fault|
    expect(fault.task).to eq(ProcessPayment)
    expect(fault.result.errors).to have_key(:amount)
  }
end

it "re-raises the original exception" do
  expect { Importer.execute!(payload: bad_json) }
    .to raise_error(JSON::ParserError)
end
```

Task-scoped matcher:

```ruby
expect { BillingWorkflow.execute! }
  .to raise_error(CMDx::Fault.for?(ChargeCard, RefundCard))
```

## Inputs

Failures produced by input resolution surface through `result.errors` with the input's **accessor name** as the key. The coerced value lives on the task instance, **not** `context` — if you need it in assertions, write it back inside `work` (`context.budget = budget`).

```ruby
it "fails when required inputs are missing" do
  result = CreateProject.execute(name: nil)

  expect(result).to be_failed
  expect(result.errors.to_h).to have_key(:name)
  expect(result.reason).to include("name")
end
```

## Outputs

Missing or invalid declared outputs fail the task with the same errors API.

```ruby
it "fails when a declared output is missing" do
  allow(JwtService).to receive(:encode).and_return(nil)

  result = AuthenticateUser.execute(email: "a@b.com", password: "pw")

  expect(result).to be_failed
  expect(result.errors).to have_key(:token)
end
```

## Retries

```ruby
it "retries transient failures" do
  call_count = 0
  allow(HTTParty).to receive(:get) do
    call_count += 1
    raise Net::ReadTimeout if call_count < 3

    double(parsed_response: { ok: true })
  end

  result = FetchExternalData.execute

  expect(result).to be_success
  expect(result.retries).to eq(2)
  expect(result).to be_retried
end
```

## Workflows

The chain contains every `Result` in execution order with the workflow's own result as the root. `origin` / `caused_failure` / `threw_failure` identify the leaf without chain scanning.

```ruby
it "runs in sequence" do
  result = OnboardingWorkflow.execute(user_data: valid_params)

  expect(result).to be_success
  expect(result.chain.size).to eq(4)
  expect(result.chain.map(&:task)).to eq(
    [OnboardingWorkflow, CreateProfile, SetupPreferences, SendWelcome]
  )
end

it "halts on first failure" do
  result = PaymentWorkflow.execute(invalid_card: true)

  expect(result).to be_failed
  expect(result.origin.task).to eq(ValidateCard)
  expect(result.caused_failure.task).to eq(ValidateCard)
end
```

`caused_failure` walks `origin` recursively to the deepest leaf; `threw_failure` returns the immediate upstream (`origin || self`).

## Callbacks

Test through observable side effects — `result` isn't available inside callbacks, so any direct unit test has to inspect `task.context`/`task.errors` instead.

```ruby
it "notifies on success" do
  allow(GuestNotifier).to receive(:call)

  ProcessBooking.execute(booking_id: booking.id)

  expect(GuestNotifier).to have_received(:call)
end
```

## Middlewares

Run through a real task:

```ruby
it "tags context before work" do
  klass = Class.new(CMDx::Task) do
    register :middleware, TaggingMiddleware.new
    def work
      context.seen = !context.tagged_at.nil?
    end
  end

  result = klass.execute

  expect(result.context.seen).to be(true)
end
```

## Direct instantiation

`Task.new(ctx)` only builds context + errors; it does **not** run the lifecycle. Use `Klass.execute` to run.

```ruby
it "holds context before execution" do
  task = CalculateShipping.new(weight: 2.5, destination: "CA")

  expect(task.context.weight).to eq(2.5)
  expect(task.errors).to be_empty
end
```

## Pattern matching

`deconstruct`: `[type, task, state, status, reason, metadata, cause, origin]`.

`deconstruct_keys` exposes: `:root`, `:type`, `:task`, `:state`, `:status`, `:reason`, `:metadata`, `:cause`, `:origin`, `:strict`, `:deprecated`, `:retries`, `:rolled_back`, `:duration`.

```ruby
it "deconstructs to array" do
  result = Build.execute(version: "1.0")

  expect(result.deconstruct)
    .to match(["Task", Build, "complete", "success", nil, {}, nil, nil])
end

it "pattern matches on failure" do
  result = Build.execute(version: nil)

  case result
  in { status: "failed", reason: String => r } then expect(r).to include("version")
  else raise "expected failed result"
  end
end
```

## Resetting state

Use `CMDx.reset_configuration!` in test setup to clear global registries (middleware, callbacks, coercions, validators, telemetry). It only clears `Task`'s cached ivars; existing user-defined subclasses keep their own caches until class reload.

```ruby
RSpec.configure do |c|
  c.before { CMDx.reset_configuration! }
end
```
