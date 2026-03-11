# Workflow Reference

For full documentation, see [docs/workflows.md](../docs/workflows.md).

## Setup

Include `CMDx::Workflow` in a `CMDx::Task` subclass:

```ruby
class MyWorkflow < CMDx::Task
  include CMDx::Workflow

  task StepOne
  task StepTwo
  task StepThree
end
```

## Task Groups

### Sequential (default)

```ruby
task StepOne
task StepTwo         # runs after StepOne completes
```

### Grouped

```ruby
tasks StepA, StepB   # same execution group, same options
```

### Parallel

```ruby
tasks StepA, StepB, strategy: :parallel
tasks StepC, StepD, strategy: :parallel, pool_size: 4
```

Uses native Ruby threads. The `pool_size` option caps the number of concurrent threads (defaults to task count).

## Breakpoints

Breakpoints control when a workflow halts on task failure or skip.

### Workflow-level (class setting)

```ruby
class MyWorkflow < CMDx::Task
  include CMDx::Workflow
  settings workflow_breakpoints: %w[skipped failed]

  task StepOne
  task StepTwo
end
```

### Group-level (overrides workflow-level)

```ruby
task StepOne, breakpoints: %w[failed]
task StepTwo, breakpoints: %w[skipped failed]
tasks StepThree, StepFour, breakpoints: []   # never halt
```

### Defaults

- `workflow_breakpoints`: `["failed"]` (halt on failure)
- Group breakpoints inherit from workflow setting unless overridden
- Empty `[]` means never halt — all tasks run regardless of status

### Behavior

When a task's result status matches the group's breakpoints, the workflow calls `throw!(task_result)` which raises a `Fault` and stops further execution.

## Conditional Execution

### Method reference

```ruby
task SendEmail, if: :email_configured?
task SkipAudit, unless: :audit_disabled?

private

def email_configured?
  context.email.present?
end
```

### Lambda/Proc

```ruby
task ApplyDiscount, if: -> { context.total > 100 }
task SendSms, unless: -> { context.phone.blank? }
```

### Combined

```ruby
task SpecialOffer, if: :eligible?, unless: :already_applied?
```

### Group-level conditions

```ruby
tasks TaskA, TaskB, TaskC, if: :group_enabled?
```

## Context Sharing

All tasks in a workflow share the same `Context` object:

```ruby
class Workflow < CMDx::Task
  include CMDx::Workflow

  task CreateUser      # sets context.user
  task CreateProfile   # reads context.user, sets context.profile
  task SendWelcome     # reads context.user and context.profile
end

result = Workflow.execute(email: "user@example.com")
result.context.user     # set by CreateUser
result.context.profile  # set by CreateProfile
```

## Error Propagation

### Default: halt on failure

```ruby
class Workflow < CMDx::Task
  include CMDx::Workflow

  task ValidateInput      # fails → workflow halts here
  task ProcessData        # never runs
  task SendNotification   # never runs
end
```

### Swallow failures (empty breakpoints)

```ruby
tasks OptionalStepA, OptionalStepB, breakpoints: []
task RequiredStep   # always runs regardless of above
```

### Mixed strategies

```ruby
class OrderWorkflow < CMDx::Task
  include CMDx::Workflow

  task ValidateOrder, breakpoints: %w[failed]
  task ChargePayment, breakpoints: %w[failed]
  tasks SendEmail, SendSms, breakpoints: [], strategy: :parallel
  task UpdateAnalytics, breakpoints: []
end
```

## Nested Workflows

Workflows can include other workflows as tasks:

```ruby
class InnerWorkflow < CMDx::Task
  include CMDx::Workflow
  task StepA
  task StepB
end

class OuterWorkflow < CMDx::Task
  include CMDx::Workflow
  task Setup
  task InnerWorkflow
  task Finalize
end
```

## Execution

```ruby
# Non-raising: returns Result even on failure
result = MyWorkflow.execute(input: data)

# Raising: raises FailFault/SkipFault on breakpoint match
result = MyWorkflow.execute!(input: data)
```

## Result Metadata for Failures

When a workflow is interrupted, the result contains failure provenance:

```ruby
result = MyWorkflow.execute(data: input)
if result.failed?
  result.metadata[:threw_failure]   # { index:, class:, ... } — task that threw
  result.metadata[:caused_failure]  # { index:, class:, ... } — root cause task
end
```
