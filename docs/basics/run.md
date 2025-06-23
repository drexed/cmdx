# Basics - Run

A run represents a collection of related task executions that share a common execution context. Runs provide unified tracking, indexing, and reporting for task workflows, making it easy to monitor complex business logic and identify all tasks involved in a single operation.

## Automatic Run Creation

Every task execution automatically creates or joins a run context:

```ruby
# Single task creates its own run
result = ProcessOrderTask.call(order_id: 123)
result.run.id       #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
result.run.results.size #=> 1
```

## Run Inheritance

When tasks call other tasks using shared context, they automatically inherit the parent's run, creating a cohesive execution trail:

```ruby
class ProcessOrderTask < CMDx::Task
  def call
    context.order = Order.find(order_id)

    # Subtasks inherit the ProcessOrderTask run_id
    SendEmailConfirmationTask.call(context)
    NotifyPartnerWarehousesTask.call(context)
  end
end

result = ProcessOrderTask.call(order_id: 123)
run = result.run

# All related tasks share the same run
run.results.size #=> 3
run.results.map(&:task).map(&:class)
#=> [ProcessOrderTask, SendEmailConfirmationTask, NotifyPartnerWarehousesTask]
```

## Run Structure and Metadata

Runs provide comprehensive execution information:

```ruby
result = ProcessOrderTask.call(order_id: 123)
run = result.run

# Run identification
run.id           #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
run.results      #=> [<CMDx::Result ...>, <CMDx::Result ...>]

# Execution state (delegates to first result)
run.state        #=> "complete"
run.status       #=> "success"
run.outcome      #=> "success"
run.runtime      #=> 0.5
```

## State Delegation

Run state information delegates to the first (primary) result, representing the overall execution outcome:

```ruby
class ProcessMainTask < CMDx::Task
  def call
    ProcessSubTask1.call(context)  # Success
    ProcessSubTask2.call(context)  # Failed
  end
end

result = ProcessMainTask.call
run = result.run

# Run status reflects the main task, not subtasks
run.status  #=> "success" (ProcessMainTask succeeded)
run.state   #=> "complete"

# Individual task results maintain their own state
run.results[0].status #=> "success" (ProcessMainTask)
run.results[1].status #=> "success" (ProcessSubTask1)
run.results[2].status #=> "failed"  (ProcessSubTask2)
```

## Result Filtering and Statistics

Runs provide methods for analyzing execution results:

```ruby
result = ProcessComplexWorkflowTask.call
run = result.run

# Filter results by status
successful_tasks = run.results.select(&:success?)
failed_tasks = run.results.select(&:failed?)
skipped_tasks = run.results.select(&:skipped?)

# Get execution statistics
total_tasks = run.results.size
success_rate = (successful_tasks.size.to_f / total_tasks * 100).round(1)

puts "Executed #{total_tasks} tasks with #{success_rate}% success rate"
puts "Failed tasks: #{failed_tasks.map { |r| r.task.class.name }.join(', ')}"
```

## Serialization and Logging

Runs provide comprehensive serialization capabilities for monitoring and debugging:

```ruby
result = ProcessOrderTask.call(order_id: 123)
run = result.run

# Hash representation with all execution data
run.to_h
#=> {
#     id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
#     state: "complete",
#     status: "success",
#     outcome: "success",
#     runtime: 0.5,
#     results: [
#       { class: "ProcessOrderTask", state: "complete", status: "success", ... },
#       { class: "SendEmailTask", state: "complete", status: "success", ... },
#       { class: "NotifyWarehousesTask", state: "complete", status: "success", ... }
#     ]
#   }

# Human-readable summary
puts run.to_s
#   Task name                     Index   Run ID      Task ID   etc
# -----------------------------------------------------------------
#=> ProcessOrderTask              0       foobar123   abc123    ...
#=> SendEmailConfirmationTask     1       foobar123   def456    ...
#=> NotifyPartnerWarehousesTask   2       foobar123   ghi789    ...
```

## Task Indexing

Runs automatically track the execution order of related tasks:

```ruby
result = ProcessMainTask.call
run = result.run

# Get index of specific results
run.index(run.results[0]) #=> 0 (first task)
run.index(run.results[1]) #=> 1 (second task)
run.index(run.results[2]) #=> 2 (third task)

# Index corresponds to execution order
run.results.each_with_index do |result, index|
  puts "#{index}: #{result.task.class.name}"
end
# 0: ProcessMainTask
# 1: ProcessSubTask1
# 2: ProcessSubTask2
```

## Run Lifecycle

Runs follow a predictable lifecycle:

1. **Creation** - New run created for initial task
2. **Inheritance** - Subtasks join existing run via context passing
3. **Population** - Results added as tasks execute
4. **Completion** - Run state reflects overall execution
5. **Freezing** - Run becomes immutable with final state

## Practical Usage Patterns

### Workflow Monitoring

```ruby
class ProcessOrderFulfillmentTask < CMDx::Task
  def call
    ValidateOrderTask.call(context)
    ChargePaymentTask.call(context)
    ReserveInventoryTask.call(context)
    ShipOrderTask.call(context)
    SendTrackingEmailTask.call(context)
  end
end

result = ProcessOrderFulfillmentTask.call(order_id: 123)

# Track entire workflow execution
run = result.run
puts "Workflow #{run.id} completed in #{run.runtime}s"
puts "Executed #{run.results.size} tasks"

# Detailed execution log
run.results.each_with_index do |task_result, index|
  status_icon = task_result.success? ? "✓" : "✗"
  puts "#{index + 1}. #{status_icon} #{task_result.task.class.name}"
end
```

### Error Analysis

```ruby
result = ProcessComplexTask.call(data: invalid_data)
run = result.run

if run.status == "failed"
  failed_tasks = run.results.select(&:failed?)

  puts "#{failed_tasks.size} tasks failed in run #{run.id}:"
  failed_tasks.each do |task_result|
    puts "- #{task_result.task.class.name}: #{task_result.metadata[:reason]}"
  end
end
```

### Performance Analysis

```ruby
result = ProcessPerformanceCriticalTask.call
run = result.run

puts "Total execution time: #{run.runtime}s"
puts "Task breakdown:"

run.results.each do |task_result|
  percentage = (task_result.runtime / run.runtime * 100).round(1)
  puts "  #{task_result.task.class.name}: #{task_result.runtime}s (#{percentage}%)"
end
```

### Audit Trail Creation

```ruby
def create_audit_trail(run)
  audit_data = {
    run_id: run.id,
    started_at: run.results.first.created_at,
    completed_at: run.results.last.updated_at,
    total_runtime: run.runtime,
    task_count: run.results.size,
    success_count: run.results.count(&:success?),
    failure_count: run.results.count(&:failed?),
    tasks: run.results.map do |result|
      {
        name: result.task.class.name,
        status: result.status,
        runtime: result.runtime,
        metadata: result.metadata
      }
    end
  }

  AuditLog.create!(audit_data)
end
```

## Best Practices

### Workflow Design

- **Use context passing** to ensure tasks inherit the same run
- **Design workflows** with clear task boundaries and responsibilities
- **Monitor run statistics** for performance and reliability insights
- **Leverage run inheritance** for automatic execution tracking

### Monitoring and Debugging

- **Use `run.to_h`** for comprehensive logging of workflow execution
- **Filter results by status** to identify problematic tasks
- **Track execution order** using task indexing for debugging
- **Monitor runtime patterns** to identify performance bottlenecks

### Error Handling

- **Analyze failed tasks** within the context of the entire run
- **Use run-level error reporting** for comprehensive failure analysis
- **Preserve run context** in error logs for better debugging
- **Implement run-based retry strategies** for transient failures

> [!TIP]
> Use runs for monitoring complex workflows. The automatic inheritance through context passing makes it easy to track all related operations without manual coordination.

> [!NOTE]
> When passing context between tasks, subtasks automatically inherit the parent's run_id, creating a unified execution trail for debugging and monitoring purposes.

---

- **Prev:** [Basics - Context](https://github.com/drexed/cmdx/blob/main/docs/basics/context.md)
- **Next:** [Interruptions - Halt](https://github.com/drexed/cmdx/blob/main/docs/interruptions/halt.md)
