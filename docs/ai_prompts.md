# AI Prompt Templates

AI prompt templates provide structured guidance for generating production-ready CMDx Task and Workflow objects. These templates ensure consistent code quality, proper framework usage, and comprehensive testing coverage when working with AI assistants.

## Table of Contents

- [TLDR](#tldr)
- [Framework Context Template](#framework-context-template)
- [Task Generation Templates](#task-generation-templates)
- [Workflow Generation Templates](#workflow-generation-templates)
- [Testing Templates](#testing-templates)
- [Error Handling and Edge Cases](#error-handling-and-edge-cases)
- [Best Practices](#best-practices)

## TLDR

> [!NOTE]
> Pre-written prompts help AI assistants generate well-structured CMDx code with proper validations, error handling, and comprehensive tests.

```ruby
# Task generation pattern
"Create a CMDx task that [ACTION] with parameters [PARAMS] and validation [RULES]"

# Workflow orchestration pattern
"Create a CMDx workflow that orchestrates [PROCESS] with steps [TASKS] and error handling [STRATEGY]"

# Testing pattern
"Generate RSpec tests with CMDx matchers for success, failure, and edge cases"
```

## Framework Context Template

> [!IMPORTANT]
> Always include this context when working with AI assistants to ensure proper CMDx code generation and adherence to framework conventions.

```
I'm working with CMDx, a Ruby framework for designing and executing business logic within service/command objects.

CORE CONCEPTS:
- Tasks inherit from CMDx::Task with business logic in `call` method
- Workflows inherit from CMDx::Workflow to orchestrate multiple tasks
- Parameters support type coercion, validation, defaults, and nesting
- Results contain status (success/failed/skipped), state, context, metadata
- Callbacks execute at lifecycle points (before_validation, on_success, etc.)
- Middlewares wrap execution (authentication, logging, timeouts, correlation)
- Chains link tasks with shared context and failure propagation

CODING STANDARDS:
- Ruby 3.4+ syntax and conventions
- snake_case methods/variables, CamelCase classes
- Double quotes for strings, proper indentation
- YARD documentation with @param, @return, @example
- RSpec tests using CMDx custom matchers
- Task naming: VerbNounTask (ProcessOrderTask)
- Workflow naming: NounVerbWorkflow (OrderProcessingWorkflow)

REQUIREMENTS:
- Production-ready code with comprehensive error handling
- Parameter validation with meaningful error messages
- Proper context management and metadata usage
- Full test coverage including edge cases and failure scenarios
```

## Task Generation Templates

### Standard Task Template

```
Create a CMDx task that [SPECIFIC_ACTION] with these requirements:

PARAMETERS:
- [name]: [type] - [description] - [required/optional] - [validation_rules]
- [name]: [type] - [description] - [default_value] - [constraints]

BUSINESS LOGIC:
1. [Validation step with error conditions]
2. [Core processing with success criteria]
3. [Side effects and external calls]
4. [Context updates and metadata]

ERROR HANDLING:
- [Specific error condition] → [failure response with metadata]
- [Edge case] → [appropriate handling strategy]

CONTEXT UPDATES:
- [key]: [description of data added]
- [key]: [metadata or tracking information]

OUTPUT:
- Complete task implementation with YARD docs
- RSpec test file with success/failure/edge cases
- Parameter validation tests
- Integration tests for external dependencies
```

### Practical Example

```
Create a CMDx task that processes user profile updates with these requirements:

PARAMETERS:
- user_id: integer - User identifier - required - positive, exists in database
- profile_data: hash - Profile information - required - non-empty hash
- send_notification: boolean - Email update notification - optional - defaults to true
- audit_reason: string - Reason for update - optional - 3-255 characters when provided

BUSINESS LOGIC:
1. Validate user exists and is active (error if not found or inactive)
2. Sanitize and validate profile data fields (reject invalid formats)
3. Update user profile in database (handle transaction failures)
4. Send notification email if enabled (log failures, don't fail task)
5. Create audit log entry with before/after values

ERROR HANDLING:
- User not found → failed with metadata {error_code: 'USER_NOT_FOUND'}
- Invalid profile data → failed with metadata {invalid_fields: [...]}
- Database failure → failed with metadata {error_code: 'DB_ERROR', retryable: true}

CONTEXT UPDATES:
- updated_user: User object with new profile data
- profile_changes: Hash with {field: [old_value, new_value]}
- notification_sent: Boolean indicating email delivery status
```

## Workflow Generation Templates

### Standard Workflow Template

```
Create a CMDx workflow that orchestrates [BUSINESS_PROCESS] with these requirements:

WORKFLOW STEPS:
1. [TaskName]: [Purpose and responsibilities]
2. [TaskName]: [Dependencies and data requirements]
3. [TaskName]: [Conditional execution criteria]

DATA FLOW:
- [Context key]: Flows from [Task A] to [Task B] for [purpose]
- [Shared state]: Available to [tasks] for [coordination]

ERROR STRATEGY:
- [Task failure] → [recovery action or compensation]
- [Critical failure] → [rollback requirements]
- [Partial failure] → [continuation strategy]

CONDITIONAL LOGIC:
- Skip [task] when [condition] is [value]
- Execute [alternative_task] if [criteria] met
- Branch execution based on [context_data]

OUTPUT:
- Complete workflow with task orchestration
- Individual task implementations
- Integration tests covering success/failure paths
- Error handling and rollback mechanisms
```

### Practical Example

```
Create a CMDx workflow that orchestrates user account deactivation with these requirements:

WORKFLOW STEPS:
1. ValidateDeactivationRequestTask: Verify user permissions and business rules
2. BackupUserDataTask: Archive user data before deactivation
3. DeactivateAccountTask: Update account status and revoke access
4. NotifyStakeholdersTask: Send notifications to relevant parties
5. UpdateAnalyticsTask: Record deactivation metrics

DATA FLOW:
- user_id: Required input, flows through all tasks
- deactivation_reason: Used by validation, backup, and analytics
- backup_reference: Created by backup, used by analytics
- stakeholder_list: Determined by validation, used by notification

ERROR STRATEGY:
- Validation failure → halt workflow, return validation errors
- Backup failure → critical error, do not proceed with deactivation
- Account deactivation failure → rollback backup, restore previous state
- Notification failure → log error, continue workflow (non-critical)
- Analytics failure → log error, workflow succeeds (tracking only)

CONDITIONAL LOGIC:
- Skip stakeholder notification if user is internal test account
- Execute priority backup for premium users
- Send different notifications based on deactivation reason
```

## Testing Templates

### Task Testing Template

> [!TIP]
> Use CMDx custom matchers for cleaner, more expressive tests that follow framework conventions.

```
Generate comprehensive RSpec tests for [TASK_NAME] including:

PARAMETER VALIDATION:
- Required parameters missing → proper error messages
- Type coercion edge cases → successful conversion or clear failures
- Validation rules → boundary conditions and invalid inputs
- Default values → proper application and override behavior

EXECUTION SCENARIOS:
- Happy path → successful execution with expected context updates
- Business rule violations → appropriate failure states with metadata
- External service failures → error handling and retry logic
- Edge cases → boundary conditions and unusual inputs

INTEGRATION POINTS:
- Database operations → transaction handling and rollback
- External APIs → network failures and response validation
- File system → permissions and storage errors
- Email/messaging → delivery failures and formatting

Use CMDx matchers:
- expect(result).to be_successful_task
- expect(result).to be_failed_task.with_metadata(hash_including(...))
- expect(result).to have_context(key: value)
- expect(TaskClass).to have_parameter(:name).with_type(:integer)
```

### Workflow Testing Template

```
Generate comprehensive RSpec tests for [WORKFLOW_NAME] including:

INTEGRATION SCENARIOS:
- Complete success path → all tasks execute with proper data flow
- Early failure → workflow halts at appropriate point
- Mid-workflow failure → proper error propagation and cleanup
- Recovery scenarios → compensation and rollback behavior

TASK COORDINATION:
- Context passing → data flows correctly between tasks
- Conditional execution → tasks skip/execute based on conditions
- Parallel execution → concurrent tasks complete properly
- Sequential dependencies → tasks wait for predecessors

ERROR PROPAGATION:
- Individual task failures → workflow response and metadata
- Critical vs non-critical failures → appropriate handling
- Rollback mechanisms → state restoration and cleanup
- Error aggregation → multiple failure consolidation

EDGE CASES:
- Empty context → proper initialization and defaults
- Malformed inputs → validation and sanitization
- Resource constraints → timeout and resource management
- Concurrent execution → race conditions and locking
```

## Error Handling and Edge Cases

> [!WARNING]
> Always include comprehensive error handling in your prompts to ensure robust, production-ready code generation.

### Common Error Scenarios

```ruby
# Parameter validation failures
expect(result).to be_failed_task
  .with_metadata(
    reason: "user_id is required",
    messages: { user_id: ["can't be blank"] }
  )

# Business rule violations
expect(result).to be_failed_task
  .with_metadata(
    error_code: "INSUFFICIENT_BALANCE",
    retryable: false,
    balance: current_balance,
    required: requested_amount
  )

# External service failures
expect(result).to be_failed_task
  .with_metadata(
    error_code: "SERVICE_UNAVAILABLE",
    retryable: true,
    retry_after: 30,
    service: "payment_processor"
  )
```

### Edge Case Coverage

Include these scenarios in your prompts:

| Scenario | Test Coverage | Expected Behavior |
|----------|---------------|-------------------|
| Empty inputs | Nil, empty strings, empty arrays | Validation errors or defaults |
| Boundary values | Min/max limits, zero, negative | Proper validation and coercion |
| Malformed data | Invalid JSON, corrupt files | Clear error messages |
| Resource limits | Memory, timeout, rate limits | Graceful degradation |
| Concurrent access | Race conditions, locks | Proper synchronization |

## Best Practices

### 1. Specific Requirements

> [!NOTE]
> Provide detailed, actionable requirements rather than vague descriptions to get better code generation.

**Effective:**
```
Create a task that validates payment information including:
- Credit card number validation using Luhn algorithm
- Expiry date validation (not expired, within 10 years)
- CVV validation (3 digits for Visa/MC, 4 for Amex)
- Amount validation (positive, max $10,000, 2 decimal places)
- Return structured validation errors with field-specific messages
```

**Ineffective:**
```
Create a payment validation task
```

### 2. Complete Context Flow

**Effective:**
```
Task receives user_id and order_data, validates inventory, processes payment,
updates order status, and adds to context:
- order: Order object with updated status
- payment_reference: Payment processor transaction ID
- inventory_reserved: Array of reserved item IDs
- processing_time: Duration in milliseconds
```

**Ineffective:**
```
Process an order and update context
```

### 3. Explicit Error Conditions

**Effective:**
```
Handle these specific errors:
- Invalid card → failed with {error_code: 'INVALID_CARD', field: 'number'}
- Expired card → failed with {error_code: 'EXPIRED', retry_date: Date}
- Declined → failed with {error_code: 'DECLINED', retryable: false}
- Timeout → failed with {error_code: 'TIMEOUT', retryable: true, delay: 30}
```

**Ineffective:**
```
Handle payment errors appropriately
```

### 4. Framework-Specific Patterns

**Effective:**
```
Follow CMDx conventions:
- Use present tense task names (ProcessPaymentTask, not PaymentProcessor)
- Include detailed metadata for failures
- Use callbacks for cross-cutting concerns (audit, logging)
- Leverage parameter coercion for input flexibility
- Return rich context updates for downstream tasks
```

**Ineffective:**
```
Use good Ruby practices
```

### 5. Comprehensive Test Coverage

**Effective:**
```
Generate tests including:
- All parameter combinations and edge cases
- Success scenarios with various input types
- Each failure mode with proper error metadata
- Integration with external services (mocked)
- Performance characteristics and timeouts
- Callback execution and order
```

**Ineffective:**
```
Include basic tests
```

---

- **Prev:** [Deprecation](deprecation.md)
- **Next:** [Tips and Tricks](tips_and_tricks.md)
