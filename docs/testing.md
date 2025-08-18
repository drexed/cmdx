# Testing

CMDx provides a comprehensive suite of custom RSpec matchers designed for expressive, maintainable testing of tasks, results, and business logic workflows.

## Table of Contents

- [TLDR](#tldr)
- [External Project Setup](#external-project-setup)
- [Matcher Organization](#matcher-organization)
- [Result Matchers](#result-matchers)
  - [Primary Outcome Matchers](#primary-outcome-matchers)
  - [State and Status Matchers](#state-and-status-matchers)
  - [Execution and Outcome Matchers](#execution-and-outcome-matchers)
  - [Metadata and Context Matchers](#metadata-and-context-matchers)
  - [Failure Chain Matchers](#failure-chain-matchers)
- [Task Matchers](#task-matchers)
  - [Structure and Lifecycle Matchers](#structure-and-lifecycle-matchers)
  - [Parameter Testing Matchers](#parameter-testing-matchers)
  - [Callback and Middleware Matchers](#callback-and-middleware-matchers)
  - [Configuration Matchers](#configuration-matchers)
- [Composable Testing](#composable-testing)
- [Error Handling](#error-handling)
- [Best Practices](#best-practices)

## TLDR

```ruby
# Setup - require in spec helper
require "cmdx/rspec/matchers"

# Result outcome matchers
expect(result).to be_successful_task(user_id: 123)
expect(result).to be_failed_task("validation_error").with_metadata(field: "email")
expect(result).to be_skipped_task.with_reason("already_processed")

# Task structure matchers
expect(MyTask).to be_well_formed_task
expect(MyTask).to have_parameter(:email).that_is_required.with_type(:string)
expect(MyTask).to have_callback(:before_execution)
```

## External Project Setup

To use CMDx's custom matchers in an external RSpec-based project, update your `spec/spec_helper.rb` or `spec/rails_helper.rb`:

```ruby
require "cmdx/rspec/matchers"
```

## Matcher Organization

CMDx matchers are organized into two primary categories with comprehensive YARD documentation:

| Category | Purpose | Matcher Count |
|----------|---------|---------------|
| **Result Matchers** | Task execution outcomes and side effects | 17 matchers |
| **Task Matchers** | Task behavior, validation, and lifecycle | 6 matchers |

> [!NOTE]
> All matchers include complete parameter descriptions, multiple usage examples, return value specifications, negation examples, and version information.

## Result Matchers

### Primary Outcome Matchers

These composite matchers validate complete task execution scenarios with single assertions:

#### Successful Task Validation

```ruby
# Basic successful task validation
expect(result).to be_successful_task

# Successful task with context validation
expect(result).to be_successful_task(user_id: 123, processed: true)

# With RSpec matchers for flexible context validation
expect(result).to be_successful_task(
  user_id: be_a(Integer),
  processed_at: be_a(Time),
  email: match(/@/)
)
```

**What it validates:**
- Result has success status
- Result is in complete state
- Result was executed
- Optional context attributes match expected values

#### Failed Task Validation

```ruby
# Basic failed task validation
expect(result).to be_failed_task

# Failed task with specific reason
expect(result).to be_failed_task("validation_failed")

# Using with_reason chain
expect(result).to be_failed_task.with_reason("invalid_data")

# Combined reason and metadata validation
expect(result).to be_failed_task("validation_error")
  .with_metadata(field: "email", rule: "format", retryable: false)
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
expect(result).to be_skipped_task("already_processed")

# Using with_reason chain
expect(result).to be_skipped_task.with_reason("order_already_processed")

# Combined reason and metadata validation
expect(result).to be_skipped_task("data_unchanged")
  .with_metadata(last_sync: be_a(Time), changes: 0)
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
# Auto-generated from CMDx::Result::STATES
expect(result).to be_initialized
expect(result).to be_executing
expect(result).to be_complete
expect(result).to be_interrupted
```

> [!IMPORTANT]
> State matchers are dynamically generated from the CMDx framework's state definitions, ensuring they stay in sync with framework updates.

#### Execution Status Matchers

```ruby
# Auto-generated from CMDx::Result::STATUSES
expect(result).to be_success
expect(result).to be_skipped
expect(result).to be_failed
```

### Execution and Outcome Matchers

```ruby
# Execution validation
expect(result).to be_executed

# Outcome classification
expect(result).to have_good_outcome  # success OR skipped
expect(result).to have_bad_outcome   # failed (not success)
```

### Metadata and Context Matchers

#### Metadata Validation

```ruby
# Basic metadata validation
expect(result).to have_metadata(validation_failed", code: 422)

# With RSpec matchers for flexible assertions
expect(result).to have_metadata(
  validation_failed",
  started_at: be_a(Time),
  duration: be > 0,
  error_code: match(/^ERR/)
)

# Chainable metadata inclusion
expect(result).to have_metadata(error")
  .including(retry_count: 3, retryable: false)

# Empty metadata validation
expect(result).to have_empty_metadata
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
expect(result).to have_runtime(be < 2.0)  # Performance constraint
```

#### Context Side Effects

```ruby
# Context validation with direct values
expect(result).to have_context(processed: true, user_id: 123)

# With RSpec matchers for flexible validation
expect(result).to have_context(
  user: have_attributes(id: 123, name: "John"),
  processed_at: be_a(Time),
  notifications: contain_exactly("email", "sms")
)

# Context preservation testing
expect(result).to have_preserved_context(
  user_id: 123,
  original_data: "important"
)
```

> [!TIP]
> Use `have_context` for testing side effects and new values, and `have_preserved_context` for verifying that certain values remained unchanged throughout execution.

#### Chain Validation

```ruby
# Chain position validation
expect(result).to have_chain_index(0)  # First task in chain
expect(result).to have_chain_index(2)  # Third task in chain

# Workflow structure testing
workflow_result = MyWorkflow.call(data: "test")
first_task = workflow_result.chain.first
expect(first_task).to have_chain_index(0)
```

### Failure Chain Matchers

Test CMDx's failure propagation patterns:

#### Original Failure Validation

```ruby
# Test that result represents an original failure (not propagated)
expect(result).to have_caused_failure

# Distinguished from thrown failures
result = ValidateDataTask.call(data: "invalid")
expect(result).to have_caused_failure
expect(result).not_to have_thrown_failure
```

#### Failure Propagation Validation

```ruby
# Basic thrown failure validation
expect(result).to have_thrown_failure

# Thrown failure with specific original result
workflow_result = MultiStepWorkflow.call(data: "problematic")
original_failure = workflow_result.chain.find(&:caused_failure?)
throwing_task = workflow_result.chain.find(&:threw_failure?)
expect(throwing_task).to have_thrown_failure(original_failure)
```

#### Received Failure Validation

```ruby
# Test that result received a thrown failure
expect(result).to have_received_thrown_failure

# Testing downstream task failure handling
workflow_result = ProcessingWorkflow.call(data: "invalid")
receiving_task = workflow_result.chain.find { |r| r.thrown_failure? }
expect(receiving_task).to have_received_thrown_failure
```

## Task Matchers

### Structure and Lifecycle Matchers

#### Well-Formed Task Validation

```ruby
# Test task meets all structural requirements
expect(MyTask).to be_well_formed_task

# For dynamically created tasks
task_class = Class.new(CMDx::Task) { def call; end }
expect(task_class).to be_well_formed_task
```

**What it validates:**
- Inherits from CMDx::Task
- Implements required call method
- Has properly initialized parameter, callback, and middleware registries

### Parameter Testing Matchers

#### Parameter Presence and Configuration

```ruby
# Basic parameter presence
expect(CreateUserTask).to have_parameter(:email)

# Parameter requirement validation
expect(ProcessOrderTask).to have_parameter(:order_id).that_is_required
expect(ConfigTask).to have_parameter(:timeout).that_is_optional

# Type coercion validation
expect(CreateUserTask).to have_parameter(:age).with_type(:integer)
expect(UpdateSettingsTask).to have_parameter(:enabled).with_coercion(:boolean)

# Default value testing
expect(ProcessTask).to have_parameter(:timeout).with_default(30)
expect(EmailTask).to have_parameter(:priority).with_default("normal")

# Validation rules testing
expect(UserTask).to have_parameter(:email)
  .with_validations(:format, :presence)
  .that_is_required
  .with_type(:string)
```

> [!WARNING]
> Parameter validation matchers test the configuration of parameters, not their runtime behavior. Use result matchers to test parameter validation failures during execution.

### Callback and Middleware Matchers

#### Callback Registration Testing

```ruby
# Basic callback registration
expect(ValidatedTask).to have_callback(:before_validation)
expect(NotifiedTask).to have_callback(:on_success)
expect(CleanupTask).to have_callback(:after_execution)

# Callback with specific callable (if supported by implementation)
expect(CustomTask).to have_callback(:on_failure).with_callable(my_proc)
```

#### Callback Execution Testing

```ruby
# Test callbacks execute during task lifecycle
expect(task_instance).to have_executed_callbacks(:before_validation, :after_validation)
expect(failed_task_instance).to have_executed_callbacks(:before_execution, :on_failure)
```

> [!NOTE]
> Callback execution testing requires task instances rather than task classes and may require mocking internal callback mechanisms for comprehensive validation.

#### Middleware Registration Testing

```ruby
# Test middleware registration
expect(AuthenticatedTask).to have_middleware(AuthenticationMiddleware)
expect(LoggedTask).to have_middleware(LoggingMiddleware)
expect(TimedTask).to have_middleware(TimeoutMiddleware)
```

### Configuration Matchers

#### Task Setting Validation

```ruby
# Test setting presence
expect(ConfiguredTask).to have_cmd_setting(:timeout)
expect(CustomTask).to have_cmd_setting(:priority)

# Test setting with specific value
expect(TimedTask).to have_cmd_setting(:timeout, 30)
expect(PriorityTask).to have_cmd_setting(:priority, "high")
```

## Composable Testing

Following RSpec best practices, CMDx matchers are designed for composition:

### Chaining with `.and`

```ruby
# Chain multiple result expectations
expect(result).to be_successful_task(user_id: 123)
  .and have_context(processed_at: be_a(Time))
  .and have_runtime(be > 0)
  .and have_chain_index(0)

# Chain task validation expectations
expect(TaskClass).to be_well_formed_task
  .and have_parameter(:user_id).that_is_required
  .and have_callback(:before_execution)
```

### Integration with Built-in RSpec Matchers

```ruby
# Combine with built-in matchers
expect(result).to be_failed_task
  .with_metadata(error_code: match(/^ERR/), retryable: be_falsy)
  .and have_caused_failure

# Complex context validation
expect(result).to be_successful_task
  .and have_context(
    user: have_attributes(id: be_a(Integer), email: match(/@/)),
    timestamps: all(be_a(Time)),
    notifications: contain_exactly("email", "sms")
  )
```

## Error Handling

### Invalid Matcher Usage

Common error scenarios and their resolution:

```ruby
# Parameter not found
expect(SimpleTask).to have_parameter(:nonexistent)
#=> "expected task to have parameter nonexistent, but had parameters: []"

# Middleware not registered
expect(SimpleTask).to have_middleware(ComplexMiddleware)
#=> "expected task to have middleware ComplexMiddleware, but had []"

# Context mismatch
expect(result).to have_context(user_id: 999)
#=> "expected context to include {user_id: 999}, but user_id: expected 999, got 123"
```

### Test Failures and Debugging

```ruby
# Use descriptive failure messages for debugging
result = ProcessDataTask.call(data: "invalid")
expect(result).to be_successful_task
#=> "expected result to be successful, but was failed,
#    expected result to be complete, but was interrupted"

# Combine matchers for comprehensive validation
expect(result).to be_failed_task("validation_error")
  .with_metadata(field: "email", rule: "format")
#=> Clear indication of what specifically failed
```

## Best Practices

### 1. Use Composite Matchers When Possible

**Preferred:**
```ruby
expect(result).to be_successful_task(user_id: 123)
```

**Instead of:**
```ruby
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

# Specific validations
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
  it "has required parameters configured" do
    expect(described_class).to have_parameter(:order_id).that_is_required
  end

  it "registers necessary callbacks" do
    expect(described_class).to have_callback(:before_execution)
  end

  context "when processing succeeds" do
    it "returns successful result with order data" do
      result = described_class.call(order_id: 123)

      expect(result).to be_successful_task(order_id: 123)
        .and have_context(order: be_present, processed_at: be_a(Time))
        .and have_runtime(be_positive)
    end
  end

  context "when validation fails" do
    it "returns failed result with error details" do
      result = described_class.call(order_id: nil)

      expect(result).to be_failed_task("validation_failed")
        .with_metadata(field: "order_id", rule: "presence")
    end
  end
end
```

### 5. Test Both Happy and Error Paths

```ruby
# Happy path
expect(result).to be_successful_task
  .and have_good_outcome
  .and have_empty_metadata

# Error path
expect(error_result).to be_failed_task
  .and have_bad_outcome
  .and have_metadata(error_code: be_present)
```

---

- **Prev:** [Internationalization (i18n)](internationalization.md)
- **Next:** [Deprecation](deprecation.md)
