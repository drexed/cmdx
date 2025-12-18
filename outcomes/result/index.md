# Outcomes - Result

Results are your window into task execution. They expose everything: outcome, state, timing, context, and metadata.

## Result Attributes

Access essential execution information:

Important

Results are immutable after execution completes.

```ruby
result = BuildApplication.execute(version: "1.2.3")

# Object data
result.task     #=> <BuildApplication>
result.context  #=> <CMDx::Context>
result.chain    #=> <CMDx::Chain>

# Execution data
result.state    #=> "interrupted"
result.status   #=> "failed"

# Fault data
result.reason   #=> "Build tool not found"
result.cause    #=> <CMDx::FailFault>
result.metadata #=> { error_code: "BUILD_TOOL.NOT_FOUND" }
```

## Lifecycle Information

Check execution state and status with predicate methods:

```ruby
result = BuildApplication.execute(version: "1.2.3")

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

Get a unified outcome string combining state and status:

```ruby
result = BuildApplication.execute(version: "1.2.3")

result.outcome #=> "success" (state and status)
```

## Chain Analysis

Trace fault origins and propagation:

```ruby
result = DeploymentWorkflow.execute(app_name: "webapp")

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
result = BuildApplication.execute(version: "1.2.3")

# Position in execution sequence
result.index #=> 0 (first task in chain)

# Access via chain
result.chain.results[result.index] == result #=> true
```

## Block Yield

Execute code with direct result access:

```ruby
BuildApplication.execute(version: "1.2.3") do |result|
  if result.success?
    notify_deployment_ready(result)
  elsif result.failed?
    handle_build_failure(result)
  else
    log_skip_reason(result)
  end
end
```

## Handlers

Handle outcomes with functional-style methods. Handlers return the result for chaining:

```ruby
result = BuildApplication.execute(version: "1.2.3")

# Status-based handlers
result
  .on(:success) { |result| notify_deployment_ready(result) }
  .on(:failed) { |result| handle_build_failure(result) }
  .on(:skipped) { |result| log_skip_reason(result) }

# State-based handlers
result
  .on(:complete) { |result| update_build_status(result) }
  .on(:interrupted) { |result| cleanup_partial_artifacts(result) }
  .on(:executed) { |result| alert_operations_team(result) } #=> .on(:complete, :interrupted)

# Outcome-based handlers
result
  .on(:good) { |result| increment_success_counter(result) } #=> .on(:success, :skipped)
  .on(:bad) { |result| alert_operations_team(result) }      #=> .on(:failed, :skipped)
```

## Pattern Matching

Use Ruby 3.0+ pattern matching for elegant outcome handling:

Important

Pattern matching works with both array and hash deconstruction.

### Array Pattern

```ruby
result = BuildApplication.execute(version: "1.2.3")

case result
in ["complete", "success"]
  redirect_to build_success_page
in ["interrupted", "failed"]
  retry_build_with_backoff(result)
in ["interrupted", "skipped"]
  log_skip_and_continue
end
```

### Hash Pattern

```ruby
result = BuildApplication.execute(version: "1.2.3")

case result
in { state: "complete", status: "success" }
  celebrate_build_success
in { status: "failed", metadata: { retryable: true } }
  schedule_build_retry(result)
in { bad: true, metadata: { reason: String => reason } }
  escalate_build_error("Build failed: #{reason}")
end
```

### Pattern Guards

```ruby
case result
in { status: "failed", metadata: { attempts: n } } if n < 3
  retry_build_with_delay(result, n * 2)
in { status: "failed", metadata: { attempts: n } } if n >= 3
  mark_build_permanently_failed(result)
in { runtime: time } if time > performance_threshold
  investigate_build_performance(result)
end
```
