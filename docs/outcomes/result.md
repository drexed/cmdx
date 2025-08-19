# Outcomes - Result

The result object is the comprehensive return value of task execution, providing complete information about the execution outcome, state, timing, and any data produced during the task lifecycle. Results serve as the primary interface for inspecting task execution outcomes and chaining task operations.

## Table of Contents

- [Result Attributes](#result-attributes)
- [Lifecycle Information](#lifecycle-information)
- [Outcome Analysis](#outcome-analysis)
- [Chain Analysis](#chain-analysis)
- [Index and Position](#index-and-position)
- [Handlers](#handlers)
- [Pattern Matching](#pattern-matching)
  - [Array Pattern](#array-pattern)
  - [Hash Pattern](#hash-pattern)
  - [Pattern Guards](#pattern-guards)

## Result Attributes

> [!NOTE]
> Result objects are immutable after task execution completes and reflect the final state.

Every result provides access to essential execution information:

```ruby
result = ProcessOrder.execute(order_id: 123)

# Object data
result.task     #=> <ProcessOrder>
result.context  #=> <CMDx::Context>
result.chain    #=> <CMDx::Chain>

# Execution data
result.state    #=> "interrupted"
result.status   #=> "failed"

# Fault data
result.reason   #=> "Unsupported payment type"
result.cause    #=> <CMDx::FailFault>
result.metadata #=> { error_code: "PAYMENT_TYPE.UNSUPPORTED" }
```

## Lifecycle Information

Results provide comprehensive methods for checking execution state and status:

```ruby
result = ProcessOrder.execute(order_id: 123)

# State predicates (execution lifecycle)
result.complete?    #=> true (successful completion)
result.interrupted? #=> false (no interruption)
result.executed?    #=> true (execution finished)

# Status predicates (execution outcome)
result.success?     #=> true (successful execution)
result.failed?      #=> false (no failure)
result.skipped?     #=> false (not skipped)

# Outcome categorization
result.good?        #=> true (success or skipped)
result.bad?         #=> false (skipped or failed)
```

## Outcome Analysis

Results provide unified outcome determination depending on the fault causal chain:

```ruby
result = ProcessOrder.execute(order_id: 123)

result.outcome #=> "success" (state and status)
```

## Chain Analysis

Use these methods to trace the root cause of faults or trace the cause points.

```ruby
result = ProcessOrderWorkflow.execute(order_id: 123)

if result.failed?
  # Find the original cause of failure
  if original_failure = result.caused_failure
    puts "Root cause: #{original_failure.task.class.name}"
    puts "Reason: #{original_failure.reason}"
  end

  # Find what threw the failure to this result
  if throwing_task = result.threw_failure
    puts "Failure source: #{throwing_task.task.class.name}"
    puts "Reason: #{throwing_task.reason}"
  end

  # Failure classification
  result.caused_failure?  #=> true if this result was the original cause
  result.threw_failure?   #=> true if this result threw a failure
  result.thrown_failure?  #=> true if this result received a thrown failure
end
```

## Index and Position

Results track their position within execution chains:

```ruby
result = ProcessOrder.execute(order_id: 123)

# Position in execution sequence
result.index #=> 0 (first task in chain)

# Access via chain
result.chain.results[result.index] == result #=> true
```

## Handlers

Use result handlers for clean, functional-style conditional logic. Handlers return the result object, enabling method chaining and fluent interfaces.

```ruby
result = ProcessOrder.execute(order_id: 123)

# Status-based handlers
result
  .on_success { |result| send_confirmation_email(result) }
  .on_failed { |result| handle_payment_failure(result) }
  .on_skipped { |result| log_skip_reason(result) }

# State-based handlers
result
  .on_complete { |result| update_order_status(result) }
  .on_interrupted { |result| cleanup_partial_state(result) }

# Outcome-based handlers
result
  .on_good { |result| increment_success_counter(result) }
  .on_bad { |result| alert_operations_team(result) }
```

## Pattern Matching

> [!NOTE]
> Pattern matching requires Ruby 3.0+. The `deconstruct` method returns a `[state, status]` array pattern, while `deconstruct_keys` provides hash access to result attributes.

Results support Ruby's pattern matching through array and hash deconstruction:

### Array Pattern

```ruby
result = ProcessOrder.execute(order_id: 123)

case result
in ["complete", "success"]
  redirect_to success_page
in ["interrupted", "failed"]
  retry_with_backoff(result)
in ["complete", "skipped"]
  log_skip_and_continue
end
```

### Hash Pattern

```ruby
result = ProcessOrder.execute(order_id: 123)

case result
in { state: "complete", status: "success" }
  celebrate_success
in { status: "failed", metadata: { retryable: true } }
  schedule_retry(result)
in { bad: true, metadata: { reason: String => reason } }
  escalate_error("Failed: #{reason}")
end
```

### Pattern Guards

```ruby
case result
in { status: "failed", metadata: { attempts: n } } if n < 3
  retry_task_with_delay(result, n * 2)
in { status: "failed", metadata: { attempts: n } } if n >= 3
  mark_permanently_failed(result)
in { runtime: time } if time > performance_threshold
  investigate_performance_issue(result)
end
```

---

- **Prev:** [Interruptions - Exceptions](../interruptions/exceptions.md)
- **Next:** [Outcomes - Statuses](statuses.md)
