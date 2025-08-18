# Outcomes - Result

The result object is the comprehensive return value of task execution, providing complete information about the execution outcome, state, timing, and any data produced during the task lifecycle. Results serve as the primary interface for inspecting task execution outcomes and chaining task operations.

## Table of Contents

- [TLDR](#tldr)
- [Core Result Attributes](#core-result-attributes)
- [State and Status Information](#state-and-status-information)
- [Execution Outcome Analysis](#execution-outcome-analysis)
- [Runtime and Performance](#runtime-and-performance)
- [Failure Chain Analysis](#failure-chain-analysis)
- [Index and Position](#index-and-position)
- [Result Callbacks and Chaining](#result-callbacks-and-chaining)
- [Pattern Matching](#pattern-matching)
- [Serialization and Inspection](#serialization-and-inspection)

## TLDR

```ruby
# Basic result inspection
result = ProcessOrder.execute(order_id: 123)
result.success?    #=> true/false
result.failed?     #=> true/false
result.runtime     #=> 0.5 (seconds)

# Fluent callbacks
result
  .on_success { |r| send_notification(r.context) }
  .on_failed { |r| handle_error(r.metadata) }

# Failure chain analysis
if result.failed?
  original = result.caused_failure    # Find root cause
  thrower = result.threw_failure      # Find failure source
end
```

## Core Result Attributes

> [!NOTE]
> Result objects are immutable after task execution completes. All result data reflects the final state of the task execution and cannot be modified.

Every result provides access to essential execution information:

```ruby
result = ProcessOrder.execute(order_id: 123)

# Core objects
result.task     #=> ProcessOrderTask instance
result.context  #=> CMDx::Context with all task data
result.chain    #=> CMDx::Chain execution tracking
result.metadata #=> Hash with execution metadata

# Execution information
result.id       #=> "abc123..." (unique execution ID)
result.state    #=> "complete"
result.status   #=> "success"
result.runtime  #=> 0.5 (execution time in seconds)
```

## State and Status Information

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
result.bad?         #=> false (failed only)
```

## Execution Outcome Analysis

Results provide unified outcome determination:

```ruby
result = ProcessOrder.execute(order_id: 123)

result.outcome #=> "success" (combines state and status)
```

## Runtime and Performance

Results capture detailed timing information for performance analysis:

```ruby
result = ProcessOrder.execute(order_id: 123)

# Execution timing
result.runtime #=> 0.5 (total execution time in seconds)

# Performance monitoring
result
  .on_executed { |r|
    MetricsService.record_execution_time(r.task.class.name, r.runtime)
  }
```

## Failure Chain Analysis

> [!IMPORTANT]
> Failure chain analysis is only available for failed results. Use these methods to trace the root cause of failures in complex task workflows.

For failed results, comprehensive failure analysis is available:

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
  end

  # Failure classification
  result.caused_failure?  #=> true if this result was the original cause
  result.threw_failure?   #=> true if this result threw a failure
  result.thrown_failure?  #=> true if this result received a thrown failure
end
```

### Error Handling Patterns

```ruby
result = ProcessPayment.execute(amount: "invalid")

if result.failed?
  case result.reason
  when /validation/i
    handle_validation_error(result)
  when /network/i
    schedule_retry(result)
  else
    escalate_error(result)
  end
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

## Result Callbacks and Chaining

> [!TIP]
> Use result callbacks for clean, functional-style conditional logic. Callbacks return the result object, enabling method chaining and fluent interfaces.

Results support fluent callback patterns for conditional logic:

```ruby
result = ProcessOrder.execute(order_id: 123)

# Status-based callbacks
result
  .on_success { |r| send_confirmation_email(r.context.email) }
  .on_failed { |r| handle_payment_failure(r) }
  .on_skipped { |r| log_skip_reason(r.reason) }

# State-based callbacks
result
  .on_complete { |r| update_order_status("processed") }
  .on_interrupted { |r| cleanup_partial_state(r.context) }

# Outcome-based callbacks
result
  .on_good { |r| increment_success_counter }
  .on_bad { |r| alert_operations_team }
```

### Practical Callback Examples

```ruby
# Order processing pipeline
ProcessOrderTask
  .execute(order_id: params[:order_id])
  .on_success { |result|
    # Chain to notification task
    SendOrderConfirmation.execute(result.context)
  }
  .on_failed { |result|
    # Handle specific failure types
    case result.metadata[:error_type]
    when "payment_declined"
      redirect_to payment_retry_path
    when "inventory_unavailable"
      redirect_to out_of_stock_path
    else
      redirect_to error_path
    end
  }
  .on_executed { |result|
    # Always log performance metrics
    Rails.logger.info "Order processing took #{result.runtime}s"
  }
```

## Pattern Matching

> [!NOTE]
> Pattern matching requires Ruby 3.0+. The `deconstruct` method returns `[state, status]` for array patterns, while `deconstruct_keys` provides hash access to result attributes.

Results support Ruby's pattern matching through array and hash deconstruction:

### Array Pattern Matching

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

### Hash Pattern Matching

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

### Pattern Matching with Guards

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

## Serialization and Inspection

Results provide comprehensive serialization and inspection capabilities:

### Hash Serialization

```ruby
result = ProcessOrder.execute(order_id: 123)

result.to_h
#=> {
#     class: "ProcessOrderTask",
#     type: "Task",
#     index: 0,
#     id: "abc123...",
#     chain_id: "def456...",
#     tags: [],
#     state: "complete",
#     status: "success",
#     outcome: "success",
#     metadata: {},
#     runtime: 0.5
#   }
```

### Human-Readable Inspection

```ruby
result = ProcessOrder.execute(order_id: 123)

result.to_s
#=> "ProcessOrderTask: type=Task index=0 id=abc123... state=complete status=success outcome=success metadata={} runtime=0.5"
```

### Failure Chain Serialization

> [!WARNING]
> Failed results include complete failure chain information. This data can be substantial in complex workflows - consider filtering when logging or persisting.

```ruby
failed_result = ProcessOrderWorkflow.execute(order_id: 123)

failed_result.to_h
#=> {
#     # ... standard result data ...
#     caused_failure: {
#       class: "ValidateOrderTask",
#       index: 1,
#       id: "xyz789...",
#       state: "interrupted",
#       status: "failed"
#     },
#     threw_failure: {
#       class: "ProcessPaymentTask",
#       index: 2,
#       id: "uvw123...",
#       state: "interrupted",
#       status: "failed"
#     }
#   }
```

---

- **Prev:** [Interruptions - Exceptions](../interruptions/exceptions.md)
- **Next:** [Outcomes - Statuses](statuses.md)
