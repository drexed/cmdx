# Basics - Execution

Task execution in CMDx provides two distinct methods that handle success and halt scenarios differently. Understanding when to use each method is crucial for proper error handling and control flow in your application workflows.

## Methods Overview

Tasks are single-use objects. Once executed, they are frozen and cannot be executed again.
Create a new instance for subsequent executions.

| Method | Returns | Exceptions | Use Case |
|--------|---------|------------|----------|
| `execute` | Always returns `CMDx::Result` | Never raises | Predictable result handling |
| `execute!` | Returns `CMDx::Result` on success | Raises `CMDx::Fault` when skipped or failed | Exception-based control flow |

## Non-bang Execution

The `execute` method always returns a `CMDx::Result` object regardless of execution outcome.
This is the preferred method for most use cases.

Any unhandled exceptions will be caught and returned as a task failure.

```ruby
result = CreateAccount.execute(email: "user@example.com")

# Check execution state
result.success?         #=> true/false
result.failed?          #=> true/false
result.skipped?         #=> true/false

# Access result data
result.context.email    #=> "user@example.com"
result.state            #=> "complete"
result.status           #=> "success"
```

## Bang Execution

The bang `execute!` method raises a `CMDx::Fault` based exception when tasks fail or are skipped, and returns a `CMDx::Result` object only on success.

It raises any unhandled non-fault exceptions caused during execution.

| Exception | Raised When |
|-----------|-------------|
| `CMDx::FailFault` | Task execution fails |
| `CMDx::SkipFault` | Task execution is skipped |

!!! warning "Important"

    `execute!` behavior depends on the `task_breakpoints` or `workflow_breakpoints` configuration. By default, it raises exceptions only on failures.

```ruby
begin
  result = CreateAccount.execute!(email: "user@example.com")
  SendWelcomeEmail.execute(result.context)
rescue CMDx::FailFault => e
  ScheduleAccountRetryJob.perform_later(e.result.context.email)
rescue CMDx::SkipFault => e
  Rails.logger.info("Account creation skipped: #{e.result.reason}")
rescue Exception => e
  ErrorTracker.capture(unhandled_exception: e)
end
```

## Direct Instantiation

Tasks can be instantiated directly for advanced use cases, testing, and custom execution patterns:

```ruby
# Direct instantiation
task = CreateAccount.new(email: "user@example.com", send_welcome: true)

# Access properties before execution
task.id                      #=> "abc123..." (unique task ID)
task.context.email           #=> "user@example.com"
task.context.send_welcome    #=> true
task.result.state            #=> "initialized"
task.result.status           #=> "success"

# Manual execution
task.execute
# or
task.execute!

task.result.success?         #=> true/false
```

## Result Details

The `Result` object provides comprehensive execution information:

```ruby
result = CreateAccount.execute(email: "user@example.com")

# Execution metadata
result.id           #=> "abc123..."  (unique execution ID)
result.task         #=> CreateAccount instance (frozen)
result.chain        #=> Task execution chain

# Context and metadata
result.context      #=> Context with all task data
result.metadata     #=> Hash with execution metadata
```

---

- **Prev:** [Basics - Setup](setup.md)
- **Next:** [Basics - Context](context.md)
