# Testing Reference

For full documentation, see [docs/testing.md](../docs/testing.md).

## RSpec Setup

```ruby
# spec/spec_helper.rb
require "cmdx"
require "cmdx/rspec"

RSpec.configure do |config|
  config.include CMDx::RSpec::Helpers
  config.include CMDx::Testing::TaskBuilders
  config.include CMDx::Testing::WorkflowBuilders

  config.before { CMDx.reset_configuration! }
  config.after  { CMDx::Chain.clear }
end
```

## RSpec Matchers

### Status matchers

```ruby
expect(result).to be_successful
expect(result).to have_skipped
expect(result).to have_skipped(reason: "Already processed")
expect(result).to have_failed
expect(result).to have_failed(reason: "Not found")
expect(result).to have_failed(reason: start_with("Invalid"))
expect(result).to have_failed(cause: be_a(CMDx::FailFault))
```

### Failure detail matchers

```ruby
expect(result).to have_failed(
  outcome: CMDx::Result::INTERRUPTED,
  threw_failure: hash_including(index: 1, class: start_with("MiddleTask")),
  caused_failure: hash_including(index: 2, class: start_with("InnerTask"))
)
```

### Context matchers

```ruby
expect(result).to have_matching_context(user: "John", token: "abc")
expect(result).to have_matching_context(executed: %i[inner middle outer])
expect(result).to have_empty_context
```

### Metadata matchers

```ruby
expect(result).to have_matching_metadata(
  errors: {
    full_message: "email must be present",
    messages: { email: ["must be present"] }
  }
)
```

### Special matchers

```ruby
expect(result).to be_dry_run
expect(result).to be_rolled_back
```

## Testing Patterns

### Success

```ruby
it "processes the payment" do
  result = ProcessPayment.execute(order_id: 1, amount: 99.99)

  expect(result).to be_successful
  expect(result).to have_matching_context(charge_id: be_present, receipt_url: be_present)
end
```

### Failure

```ruby
it "fails when order not found" do
  result = ProcessPayment.execute(order_id: -1, amount: 99.99)

  expect(result).to have_failed(reason: "Order not found")
end
```

### Skip

```ruby
it "skips already processed orders" do
  result = ProcessPayment.execute(order_id: processed_order.id, amount: 99.99)

  expect(result).to have_skipped(reason: "Already processed")
end
```

### Validation errors

```ruby
it "fails with missing required attributes" do
  result = ProcessPayment.execute(order_id: nil)

  expect(result).to have_failed(reason: "Invalid")
  expect(result).to have_matching_metadata(
    errors: {
      messages: { order_id: [be_a(String)] }
    }
  )
end
```

### Bang execution

```ruby
it "raises on failure with execute!" do
  expect {
    ProcessPayment.execute!(order_id: -1, amount: 99.99)
  }.to raise_error(CMDx::FailFault, "Order not found")
end
```

### Dry run

```ruby
it "supports dry run" do
  result = ProcessPayment.execute(order_id: 1, amount: 99.99, dry_run: true)

  expect(result).to be_dry_run
  expect(result).to be_successful
end
```

### Returns validation

```ruby
it "fails when returns are missing" do
  result = IncompleteTask.execute(data: input)

  expect(result).to have_failed(reason: "Invalid")
  expect(result).to have_matching_metadata(
    errors: { messages: { user: [be_a(String)] } }
  )
end
```

### Workflows

```ruby
it "executes all tasks in order" do
  result = OnboardCustomer.execute(email: "test@example.com", plan: "pro")

  expect(result).to be_successful
  expect(result).to have_matching_context(
    user: be_present,
    profile: be_present,
    welcome_sent: true
  )
end

it "halts on task failure" do
  result = OnboardCustomer.execute(email: nil)

  expect(result).to have_failed
end
```

### Callbacks

```ruby
it "invokes callbacks in order" do
  result = MyTask.execute(data: input)

  expect(result).to be_successful
  expect(result).to have_matching_context(
    callbacks: %i[before_validation before_execution on_complete on_executed on_success on_good]
  )
end
```

### Result handlers

```ruby
it "invokes the correct handler" do
  handled = []
  result = MyTask.execute(data: input)
  result.on(:success) { handled << :success }
        .on(:failed)  { handled << :failed }

  expect(handled).to eq([:success])
end
```

### Pattern matching

```ruby
it "supports pattern matching" do
  result = MyTask.execute(data: input)

  case result
  in ["complete", "success"]
    expect(result.context.output).to be_present
  in ["interrupted", "failed"]
    fail "unexpected failure"
  end
end
```

## Task Builders

Helpers for creating test task classes:

```ruby
# Base builder
task_class = create_task_class do
  required :input, type: :string
  def work
    context.output = input.upcase
  end
end

# Named task
task_class = create_task_class(name: "CustomName") do
  def work = nil
end

# Inheriting
child = create_task_class(base: ParentTask) do
  optional :extra
  def work
    super
    context.extra = extra
  end
end

# Preset builders
create_successful_task   # work pushes :success to context.executed
create_skipping_task     # work calls skip!
create_failing_task      # work calls fail!
create_erroring_task     # work raises CMDx::TestError
```

## Workflow Builders

```ruby
workflow = create_workflow_class do
  task TaskA
  task TaskB
end

# Preset builders
create_successful_workflow
create_skipping_workflow
create_failing_workflow
create_erroring_workflow
```

## Test Isolation

Always reset between tests to avoid state leakage:

```ruby
config.before { CMDx.reset_configuration! }
config.after  { CMDx::Chain.clear }
config.after  { CMDx::Middlewares::Correlate.clear }
```
