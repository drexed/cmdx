# Basics - Run

A run represents a collection of related task executions that share a common execution context. Runs provide unified tracking, indexing, and reporting for task workflows, making it easy to monitor complex business logic and identify all tasks involved in a single operation.

## Table of Contents

- [Automatic Run Creation](#automatic-run-creation)
- [Run Inheritance](#run-inheritance)
- [Run Structure and Metadata](#run-structure-and-metadata)
- [State Delegation](#state-delegation)
- [Result Filtering and Statistics](#result-filtering-and-statistics)
- [Serialization and Logging](#serialization-and-logging)
- [Task Indexing](#task-indexing)
- [Run Lifecycle](#run-lifecycle)

## Automatic Run Creation

Every task execution automatically creates or joins a run context:

```ruby
# Single task creates its own run
result = ProcessUserOrderTask.call(order_id: 123)
result.run.id           #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
result.run.results.size #=> 1
```

## Run Inheritance

When tasks call other tasks using shared context, they automatically inherit the parent's run, creating a cohesive execution trail:

```ruby
class ProcessUserOrderTask < CMDx::Task
  def call
    context.order = Order.find(order_id)

    # Subtasks inherit the ProcessUserOrderTask run_id
    SendOrderConfirmationTask.call(context)
    NotifyWarehousePartnersTask.call(context)
  end
end

result = ProcessUserOrderTask.call(order_id: 123)
run = result.run

# All related tasks share the same run
run.results.size #=> 3
run.results.map(&:task).map(&:class)
#=> [ProcessUserOrderTask, SendOrderConfirmationTask, NotifyWarehousePartnersTask]
```

> [!NOTE]
> When passing context between tasks, subtasks automatically inherit the parent's run_id, creating a unified execution trail for debugging and monitoring purposes.

## Run Structure and Metadata

Runs provide comprehensive execution information:

```ruby
result = ProcessUserOrderTask.call(order_id: 123)
run = result.run

# Run identification
run.id      #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
run.results #=> [<CMDx::Result ...>, <CMDx::Result ...>]

# Execution state (delegates to first result)
run.state   #=> "complete"
run.status  #=> "success"
run.outcome #=> "success"
run.runtime #=> 0.5
```

## State Delegation

Run state information delegates to the first (primary) result, representing the overall execution outcome:

```ruby
class ProcessOrderTask < CMDx::Task
  def call
    ValidateOrderDataTask.call(context)   # Success
    ProcessOrderPaymentTask.call(context) # Failed
  end
end

result = ProcessOrderTask.call
run = result.run

# Run status reflects the main task, not subtasks
run.status            #=> "success" (ProcessOrderTask succeeded)
run.state             #=> "complete"

# Individual task results maintain their own state
run.results[0].status #=> "success" (ProcessOrderTask)
run.results[1].status #=> "success" (ValidateOrderDataTask)
run.results[2].status #=> "failed"  (ProcessOrderPaymentTask)
```

> [!IMPORTANT]
> Run state always reflects the primary (first) task outcome, not the subtasks. Individual subtask results maintain their own success/failure states.

## Result Filtering and Statistics

Runs provide methods for analyzing execution results:

```ruby
result = ProcessLargeOrderTask.call
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
result = ProcessUserOrderTask.call(order_id: 123)
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
#       { class: "ProcessUserOrderTask", state: "complete", status: "success", ... },
#       { class: "SendOrderConfirmationTask", state: "complete", status: "success", ... },
#       { class: "NotifyWarehousePartnersTask", state: "complete", status: "success", ... }
#     ]
#   }

# Human-readable summary
puts run.to_s
#   Task name                     Index   Run ID      Task ID   etc
# -----------------------------------------------------------------
#=> ProcessUserOrderTask          0       foobar123   abc123    ...
#=> SendOrderConfirmationTask     1       foobar123   def456    ...
#=> NotifyWarehousePartnersTask   2       foobar123   ghi789    ...
```

## Task Indexing

Runs automatically track the execution order of related tasks:

```ruby
result = ProcessOrderTask.call
run = result.run

# Get index of specific results
run.index(run.results[0]) #=> 0 (first task)
run.index(run.results[1]) #=> 1 (second task)
run.index(run.results[2]) #=> 2 (third task)

# Index corresponds to execution order
run.results.each_with_index do |result, index|
  puts "#{index}: #{result.task.class.name}"
end
# 0: ProcessOrderTask
# 1: ValidateOrderDataTask
# 2: ProcessOrderPaymentTask
```

## Run Lifecycle

Runs follow a predictable lifecycle:

1. **Creation** - New run created for initial task
2. **Inheritance** - Subtasks join existing run via context passing
3. **Population** - Results added as tasks execute
4. **Completion** - Run state reflects overall execution
5. **Freezing** - Run becomes immutable with final state

> [!TIP]
> Use runs for monitoring complex workflows. The automatic inheritance through context passing makes it easy to track all related operations without manual coordination.

---

- **Prev:** [Basics - Context](https://github.com/drexed/cmdx/blob/main/docs/basics/context.md)
- **Next:** [Interruptions - Halt](https://github.com/drexed/cmdx/blob/main/docs/interruptions/halt.md)
