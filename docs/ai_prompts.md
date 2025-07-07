# AI Prompt Templates

This guide provides AI prompt templates for building CMDx Task and Workflow objects, helping you leverage AI assistants to generate well-structured, production-ready command objects.

## Table of Contents

- [TLDR](#tldr)
- [Framework Context Template](#framework-context-template)
- [Task Generation Templates](#task-generation-templates)
- [Workflow Generation Templates](#workflow-generation-templates)
- [Testing Templates](#testing-templates)
- [Best Practices for AI Prompts](#best-practices-for-ai-prompts)

## TLDR

- **Purpose** - Pre-written prompts to help AI assistants generate production-ready CMDx code
- **Templates** - Framework context, task generation, workflow generation, and testing templates
- **Framework context** - Essential CMDx concepts and coding standards for AI understanding
- **Task templates** - Structured prompts for generating tasks with parameters, validations, and tests
- **Workflow templates** - Prompts for orchestrating multi-step business processes
- **Testing templates** - Comprehensive RSpec test generation with CMDx matchers

## Framework Context Template

Use this context in your AI conversations to ensure proper CMDx code generation:

```
I'm working with CMDx, a Ruby framework for designing and executing business logic within service/command objects.

KEY FRAMEWORK CONCEPTS:
- Tasks inherit from CMDx::Task and implement business logic in a `call` method
- Workflows inherit from CMDx::Workflow and orchestrate multiple tasks
- Parameters are defined with type coercion, validation, and defaults
- Results contain status (success/failed/skipped), state, context, and metadata
- Callbacks execute at specific lifecycle points (before_validation, on_success, etc.)
- Middlewares wrap task execution (authentication, logging, timeouts)
- Chains link multiple tasks together with shared context

CODING STANDARDS:
- Use Ruby 3.4+ syntax and conventions
- Follow snake_case for methods/variables, CamelCase for classes
- Use double quotes for strings
- Include comprehensive YARD documentation
- Write RSpec tests with CMDx custom matchers
- Name tasks as VerbNounTask (e.g., ProcessOrderTask)
- Name workflows as NounVerbWorkflow (e.g., OrderProcessingWorkflow)

Generate code that is production-ready with proper error handling, validation, and testing.
```

## Task Generation Templates

```
Create a CMDx task that [SPECIFIC_ACTION] with the following requirements:

PARAMETERS:
- [parameter_name]: [type] - [description] - [required/optional]
- [parameter_name]: [type] - [description] - [validation_rules]

BUSINESS LOGIC:
- [Step 1 description]
- [Step 2 description]
- [Error conditions to handle]

CONTEXT UPDATES:
- [What data should be added to context]
- [What side effects should occur]

TESTING:
- Generate comprehensive RSpec tests using CMDx matchers
- Include success, failure, and edge case scenarios
- Test parameter validation and context updates

Please include:
- Proper parameter definitions with validations
- Error handling and metadata
- YARD documentation
- RSpec test file
```

**Example Usage:**
```
Create a CMDx task that processes user email preferences with the following requirements:

PARAMETERS:
- user_id: integer - ID of the user - required, positive
- email_types: array - Types of emails to enable - required, inclusion in ['marketing', 'notifications', 'alerts']
- enabled: boolean - Whether to enable or disable - optional, defaults to true

BUSINESS LOGIC:
- Validate user exists and is active
- Update user's email preferences in database
- Send confirmation email if preferences changed
- Log preference changes for audit trail

CONTEXT UPDATES:
- Add updated user object to context
- Add preference_changes hash with before/after values
- Add confirmation_sent boolean

TESTING:
- Generate comprehensive RSpec tests using CMDx matchers
- Include success, failure, and edge case scenarios
- Test parameter validation and context updates
```

## Workflow Generation Templates

```
Create a CMDx workflow that orchestrates [BUSINESS_PROCESS] with the following requirements:

WORKFLOW STEPS:
1. [Task 1]: [Description and purpose]
2. [Task 2]: [Description and purpose]
3. [Task 3]: [Description and purpose]

TASK DEPENDENCIES:
- [How tasks share data through context]
- [Which tasks can run in parallel]
- [Sequential requirements]

ERROR HANDLING:
- [How to handle individual task failures]
- [Rollback requirements]
- [Compensation logic]

CONDITIONAL LOGIC:
- [When to skip certain tasks]
- [Branching based on context]

TESTING:
- Generate workflow integration tests
- Test success path and various failure scenarios
- Include individual task unit tests
```

**Example Usage:**
```
Create a CMDx workflow that orchestrates user onboarding with the following requirements:

WORKFLOW STEPS:
1. ValidateUserDataTask: Validate and sanitize user registration data
2. CreateUserAccountTask: Create user account in database
3. SendWelcomeEmailTask: Send personalized welcome email
4. SetupDefaultPreferencesTask: Configure default user preferences
5. TrackOnboardingEventTask: Log onboarding completion for analytics

TASK DEPENDENCIES:
- All tasks run sequentially
- User data flows through context from validation to account creation
- Welcome email uses created user object
- Preferences setup requires user ID
- Analytics tracking happens last with full context

ERROR HANDLING:
- If account creation fails, don't send email or setup preferences
- If email fails, continue with preferences but log the failure
- If preferences fail, still complete onboarding but flag for followup

CONDITIONAL LOGIC:
- Skip welcome email if user opted out during registration
- Skip analytics if user has privacy settings enabled

TESTING:
- Generate workflow integration tests
- Test success path and various failure scenarios
- Include individual task unit tests
```

## Testing Templates

### Task Testing Template

```
Generate comprehensive RSpec tests for [TASK_NAME] including:

PARAMETER VALIDATION TESTS:
- Test all required parameters
- Test type coercion and validation rules
- Test default values
- Test invalid parameter combinations

EXECUTION TESTS:
- Test successful execution with various inputs
- Test all error conditions and edge cases
- Test context updates and side effects
- Test metadata and timing information

INTEGRATION TESTS:
- Test external service interactions
- Test database operations
- Test file system operations (if applicable)

CALLBACK TESTS:
- Test lifecycle callbacks execute correctly
- Test callback order and context

Use CMDx custom matchers like:
- expect(result).to be_successful_task
- expect(result).to be_failed_task
- expect(TaskClass).to handle_exceptions_gracefully
```

### Workflow Testing Template

```
Generate comprehensive RSpec tests for [WORKFLOW_NAME] including:

INTEGRATION TESTS:
- Test complete workflow execution
- Test various success scenarios
- Test different failure points
- Test context flow between tasks

INDIVIDUAL TASK TESTS:
- Test each task in isolation
- Test task parameter validation
- Test task-specific logic

CONDITIONAL LOGIC TESTS:
- Test all branching paths
- Test edge cases in decision logic
- Test context preservation across branches

ERROR HANDLING TESTS:
- Test failure propagation
- Test recovery mechanisms
- Test compensation logic
```

## Best Practices for AI Prompts

### 1. Be Specific About Requirements

**Good:**
```
Create a task that validates credit card information, including:
- Card number validation with Luhn algorithm
- Expiry date validation (not expired, reasonable future date)
- CVV validation (3-4 digits depending on card type)
- Cardholder name validation (2-50 characters, letters and spaces only)
```

**Avoid:**
```
Create a task that validates credit cards
```

### 2. Include Context About Data Flow

**Good:**
```
The task should receive user_id and payment_amount, validate the payment method,
charge the card, and update the context with:
- transaction_id
- charged_amount
- payment_method_last_four
- charge_timestamp
```

**Avoid:**
```
Process a payment
```

### 3. Specify Error Conditions

**Good:**
```
Handle these error conditions:
- Invalid card number → failed result with metadata { error_code: 'INVALID_CARD' }
- Expired card → failed result with metadata { error_code: 'EXPIRED_CARD' }
- Insufficient funds → failed result with metadata { error_code: 'DECLINED', retryable: false }
- Network timeout → failed result with metadata { error_code: 'TIMEOUT', retryable: true }
```

**Avoid:**
```
Handle payment errors
```

### 4. Request Complete Examples

**Good:**
```
Generate a complete working example including:
- Task class with full implementation
- Parameter definitions with validations
- RSpec test file with success/failure scenarios
- YARD documentation
- Usage examples in comments
```

**Avoid:**
```
Show me the basic structure
```

### 5. Specify Framework Patterns

**Good:**
```
Follow CMDx patterns:
- Use present tense verbs in task names (ProcessPaymentTask, not ProcessingPaymentTask)
- Include proper error handling with metadata
- Use callbacks for audit logging
- Return detailed context updates
- Include comprehensive parameter validation
```

**Avoid:**
```
Use best practices
```

---

- **Prev:** [Testing](testing.md)
- **Next:** [Tips and Tricks](tips_and_tricks.md)
