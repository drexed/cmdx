# Testing

CMDx provides a comprehensive suite of custom RSpec matchers designed for expressive, maintainable testing of tasks, results, and business logic workflows.

## Table of Contents

- [External Project Setup](#external-project-setup)
- [Matcher Organization](#matcher-organization)
- [Result Matchers](#result-matchers)
  - [Primary Outcome Matchers](#primary-outcome-matchers)
  - [State and Status Matchers](#state-and-status-matchers)
  - [Metadata and Context Matchers](#metadata-and-context-matchers)
  - [Failure Chain Matchers](#failure-chain-matchers)
- [Task Matchers](#task-matchers)
  - [Parameter Validation Matchers](#parameter-validation-matchers)
  - [Lifecycle and Structure Matchers](#lifecycle-and-structure-matchers)
  - [Exception Handling Matchers](#exception-handling-matchers)
  - [Callback and Middleware Matchers](#callback-and-middleware-matchers)
  - [Configuration Matchers](#configuration-matchers)
- [Composable Testing](#composable-testing)
- [Best Practices](#best-practices)

## Using RSpec matchers

To use CMDx's custom matchers in an external RSpec-based project update your `spec/spec_helper.rb` or `spec/rails_helper.rb`:

```ruby
require "cmdx/rspec/result_matchers"
require "cmdx/rspec/task_matchers"
```

## Matcher Organization

CMDx matchers are organized into two primary files with comprehensive YARD documentation:

| File | Purpose | Matcher Count |
|------|---------|---------------|
| `result_matchers.rb` | Task execution outcomes and side effects | 25+ matchers |
| `task_matchers.rb` | Task behavior, validation, and lifecycle | 15+ matchers |

All matchers include:
- Complete parameter descriptions
- Multiple usage examples
- Return value specifications
- Negation examples
- Version information

## Result Matchers

### Primary Outcome Matchers

These composite matchers validate complete task execution scenarios with single assertions:

#### Successful Task Validation

```ruby
# Basic successful task validation
expect(result).to be_successful_task

# Successful task with context validation
expect(result).to be_successful_task(user_id: 123, processed: true)

# Negated usage
expect(result).not_to be_successful_task
```

**What it validates:**
- Result has success status
- Result is in complete state
- Result was executed
- Optional context attributes match

#### Failed Task Validation

```ruby
# Basic failed task validation
expect(result).to be_failed_task

# Failed task with specific reason
expect(result).to be_failed_task("Validation failed")

# Chainable reason and metadata validation
expect(result).to be_failed_task
  .with_reason("Invalid data")
  .with_metadata(error_code: "ERR001", retryable: false)

# Negated usage
expect(result).not_to be_failed_task
```

**What it validates:**
- Result has failed status
- Result is in interrupted state
- Result was executed
- Optional reason and metadata match

#### Skipped Task Validation

```ruby
# Basic skipped task validation
expect(result).to be_skipped_task

# Skipped task with specific reason
expect(result).to be_skipped_task("Already processed")

# Chainable reason and metadata validation
expect(result).to be_skipped_task
  .with_reason("Order already processed")
  .with_metadata(processed_at: be_a(Time), skip_code: "DUPLICATE")

# Negated usage
expect(result).not_to be_skipped_task
```

**What it validates:**
- Result has skipped status
- Result is in interrupted state
- Result was executed
- Optional reason and metadata match

### State and Status Matchers

Individual validation matchers for granular testing:

#### Execution State Matchers

```ruby
# Individual state checks (auto-generated from CMDx::Result::STATES)
expect(result).to be_initialized
expect(result).to be_executing
expect(result).to be_complete
expect(result).to be_interrupted

# Negated usage
expect(result).not_to be_initialized
```

#### Execution Status Matchers

```ruby
# Individual status checks (auto-generated from CMDx::Result::STATUSES)
expect(result).to be_success
expect(result).to be_skipped
expect(result).to be_failed

# Negated usage
expect(result).not_to be_success
```

#### Execution and Outcome Matchers

```ruby
# Execution validation
expect(result).to be_executed

# Outcome classification
expect(result).to have_good_outcome  # success OR skipped
expect(result).to have_bad_outcome   # not success (includes skipped and failed)

# Negated usage
expect(result).not_to be_executed
expect(result).not_to have_good_outcome
```

### Metadata and Context Matchers

#### Metadata Validation

```ruby
# Basic metadata validation with RSpec matcher support
expect(result).to have_metadata(reason: "Error", code: "001")
expect(result).to have_metadata(
  reason: "Invalid email format",
  errors: ["Email must contain @"],
  error_code: "VALIDATION_FAILED",
  retryable: false,
  failed_at: be_a(Time)
)

# Chainable metadata inclusion
expect(result).to have_metadata(reason: "Error")
  .including(code: "001", retryable: false)

# Empty metadata validation
expect(result).to have_empty_metadata

# Negated usage
expect(result).not_to have_metadata(reason: "Different error")
```

#### Runtime Validation

```ruby
# Basic runtime presence validation
expect(result).to have_runtime

# Runtime with specific value
expect(result).to have_runtime(0.5)

# Runtime with RSpec matchers
expect(result).to have_runtime(be > 0)
expect(result).to have_runtime(be_within(0.1).of(0.5))

# Negated usage
expect(result).not_to have_runtime
```

#### Context Side Effects

```ruby
# Context validation with RSpec matcher support
expect(result).to have_context(processed: true, user_id: 123)
expect(result).to have_context(
  processed_at: be_a(Time),
  errors: be_empty,
  count: be > 0
)

# Complex side effects validation
expect(result).to have_context(
  user: have_attributes(id: 123, name: "John"),
  notifications: contain_exactly("email", "sms")
)

# Context preservation
expect(result).to preserve_context(original_data)

# Negated usage
expect(result).not_to have_context(deleted: true)
```

#### Chain Validation

```ruby
# Basic chain membership validation
expect(result).to belong_to_chain

# Specific chain validation
expect(result).to belong_to_chain(my_chain)

# Chain position validation
expect(result).to have_chain_index(0)  # First task in chain
expect(result).to have_chain_index(2)  # Third task in chain

# Negated usage
expect(result).not_to belong_to_chain
expect(result).not_to have_chain_index(1)
```

### Failure Chain Matchers

Test CMDx's failure propagation patterns:

#### Original Failure Validation

```ruby
# Test that result represents an original failure (not propagated)
expect(result).to have_caused_failure

# Negated usage (for thrown failures)
expect(result).not_to have_caused_failure
```

#### Failure Propagation Validation

```ruby
# Basic thrown failure validation
expect(result).to have_thrown_failure

# Thrown failure with specific original result
expect(result).to have_thrown_failure(original_failed_result)

# Negated usage (for caused failures)
expect(result).not_to have_thrown_failure
```

#### Received Failure Validation

```ruby
# Test that result received a thrown failure
expect(result).to have_received_thrown_failure

# Negated usage
expect(result).not_to have_received_thrown_failure
```

## Task Matchers

### Parameter Validation Matchers

Test task parameter validation behavior:

#### Required Parameter Validation

```ruby
# Test that task validates required parameters
expect(CreateUserTask).to validate_required_parameter(:email)
expect(ProcessOrderTask).to validate_required_parameter(:order_id)

# Negated usage
expect(OptionalTask).not_to validate_required_parameter(:optional_field)
```

**How it works:** Calls the task without the parameter and ensures it fails with appropriate validation message.

#### Type Validation

```ruby
# Test parameter type coercion validation
expect(CreateUserTask).to validate_parameter_type(:age, :integer)
expect(UpdateSettingsTask).to validate_parameter_type(:enabled, :boolean)
expect(SearchTask).to validate_parameter_type(:filters, :hash)

# Negated usage
expect(FlexibleTask).not_to validate_parameter_type(:flexible_param, :string)
```

**How it works:** Passes invalid type values and ensures task fails with type validation message.

#### Default Value Testing

```ruby
# Test parameter default values
expect(ProcessTask).to use_default_value(:timeout, 30)
expect(EmailTask).to use_default_value(:priority, "normal")
expect(ConfigTask).to use_default_value(:enabled, true)

# Negated usage
expect(RequiredParamTask).not_to use_default_value(:required_field, nil)
```

**How it works:** Calls task without the parameter and verifies the expected default value appears in context.

### Lifecycle and Structure Matchers

#### Well-Formed Task Validation

```ruby
# Test task meets all structural requirements
expect(MyTask).to be_well_formed_task
expect(UserCreationTask).to be_well_formed_task

# Negated usage (for malformed tasks)
expect(BrokenTask).not_to be_well_formed_task
```

**What it validates:**
- Inherits from CMDx::Task
- Implements required call method
- Has properly initialized parameter, callback, and middleware registries

#### Single-Use Pattern Validation

```ruby
# Test task follows single-use instance pattern
expect(MyTask).to follow_single_use_pattern
expect(ProcessingTask).to follow_single_use_pattern

# Negated usage (for reusable task implementations)
expect(ReusableTask).not_to follow_single_use_pattern
```

**What it validates:**
- Each instance has unique identifier
- Instances become frozen after execution
- Multiple executions of same instance are prevented

#### Execution Lifecycle Validation

```ruby
# Test task becomes frozen after execution
expect(MyTask).to be_frozen_after_execution

# Test task prevents multiple executions
expect(MyTask).to prevent_multiple_executions

# Negated usage
expect(MutableTask).not_to be_frozen_after_execution
expect(ReusableTask).not_to prevent_multiple_executions
```

### Exception Handling Matchers

#### Graceful Exception Handling

```ruby
# Test task converts exceptions to failed results
expect(RobustTask).to handle_exceptions_gracefully

# Negated usage (for exception-propagating tasks)
expect(StrictTask).not_to handle_exceptions_gracefully
```

**How it works:** Injects exception-raising logic and verifies exceptions are caught and converted to failed results.

#### Bang Method Exception Propagation

```ruby
# Test task propagates exceptions with call!
expect(MyTask).to propagate_exceptions_with_bang

# Negated usage (for always-graceful tasks)
expect(AlwaysGracefulTask).not_to propagate_exceptions_with_bang
```

**How it works:** Tests that `call!` method propagates exceptions instead of handling them gracefully.

### Callback and Middleware Matchers

#### Callback Registration Testing

```ruby
# Test basic callback registration
expect(ValidatedTask).to have_callback(:before_validation)
expect(NotifiedTask).to have_callback(:on_success)
expect(CleanupTask).to have_callback(:after_execution)

# Test callback with specific callable
expect(CustomTask).to have_callback(:on_failure).with_callable(my_proc)

# Negated usage
expect(SimpleTask).not_to have_callback(:complex_callback)
```

#### Callback Execution Testing

```ruby
# Test callbacks execute during task lifecycle
expect(task).to execute_callbacks(:before_validation, :after_validation)
expect(failed_task).to execute_callbacks(:before_execution, :on_failure)

# Single callback execution
expect(simple_task).to execute_callbacks(:on_success)

# Negated usage
expect(task).not_to execute_callbacks(:unused_callback)
```

> [!NOTE]
> Callback execution testing may require mocking internal callback mechanisms for comprehensive validation.

#### Middleware Registration Testing

```ruby
# Test middleware registration
expect(AuthenticatedTask).to have_middleware(AuthenticationMiddleware)
expect(LoggedTask).to have_middleware(LoggingMiddleware)
expect(TimedTask).to have_middleware(TimeoutMiddleware)

# Negated usage
expect(SimpleTask).not_to have_middleware(ComplexMiddleware)
```

### Configuration Matchers

#### Task Setting Validation

```ruby
# Test setting presence
expect(ConfiguredTask).to have_task_setting(:timeout)
expect(CustomTask).to have_task_setting(:priority)

# Test setting with specific value
expect(TimedTask).to have_task_setting(:timeout, 30)
expect(PriorityTask).to have_task_setting(:priority, "high")

# Negated usage
expect(SimpleTask).not_to have_task_setting(:complex_setting)
```

## Composable Testing

Following RSpec best practices, CMDx matchers are designed for composition:

### Chaining with `.and`

```ruby
# Chain multiple result expectations
expect(result).to be_successful_task(user_id: 123)
  .and have_context(processed_at: be_a(Time))
  .and have_runtime(be > 0)
  .and belong_to_chain

# Chain task validation expectations
expect(TaskClass).to be_well_formed_task
  .and validate_required_parameter(:user_id)
  .and have_callback(:before_execution)
  .and handle_exceptions_gracefully
```

### Integration with Built-in RSpec Matchers

```ruby
# Combine with built-in matchers
expect(result).to be_failed_task
  .with_metadata(error_code: "ERR001", retryable: be_falsy)
  .and have_caused_failure

# Use in complex scenarios
expect(result).to be_successful_task
  .and have_context(
    user: have_attributes(id: be_a(Integer), email: match(/@/)),
    timestamps: all(be_a(Time)),
    notifications: contain_exactly("email", "sms")
  )
```

### Conditional Testing

```ruby
# Conditional expectations based on environment
if Rails.env.production?
  expect(result).to have_metadata(tracking_id: be_present)
else
  expect(result).to have_metadata(debug_info: be_present)
end

# Dynamic testing based on result status
case result.status
when 'success'
  expect(result).to have_context(processed_at: be_a(Time))
when 'failed'
  expect(result).to have_metadata(error_code: be_present)
when 'skipped'
  expect(result).to have_metadata(reason: be_present)
end
```

## Best Practices

### 1. Use Composite Matchers When Possible

**Preferred:**
```ruby
expect(result).to be_successful_task(user_id: 123)
```

**Instead of:**
```ruby
expect(result).to be_a(CMDx::Result)
expect(result).to be_success
expect(result).to be_complete
expect(result).to be_executed
expect(result.context.user_id).to eq(123)
```

### 2. Combine Granular and Composite Testing

Use composite matchers for primary assertions, granular matchers for specific edge cases:

```ruby
# Primary assertion
expect(result).to be_successful_task

# Specific edge case validation
expect(result).to have_runtime(be < 1.0)  # Performance requirement
expect(result).to have_chain_index(0)     # Position validation
```

### 3. Leverage RSpec Matcher Integration

CMDx matchers work seamlessly with built-in RSpec matchers:

```ruby
expect(result).to have_metadata(
  timestamp: be_within(1.second).of(Time.current),
  errors: be_empty,
  count: be_between(1, 100)
)
```

### 4. Write Descriptive Test Names

Matcher names are designed to read naturally in test descriptions:

```ruby
describe ProcessOrderTask do
  it "validates required parameters" do
    expect(described_class).to validate_required_parameter(:order_id)
  end

  it "handles exceptions gracefully" do
    expect(described_class).to handle_exceptions_gracefully
  end

  context "when processing succeeds" do
    it "returns successful result with order data" do
      result = described_class.call(order_id: 123)

      expect(result).to be_successful_task(order_id: 123)
        .and have_context(order: be_present, processed_at: be_a(Time))
        .and have_runtime(be_positive)
    end
  end
end
```

---

- **Prev:** [Logging](logging.md)
- **Next:** [Tips and Tricks](tips_and_tricks.md)
