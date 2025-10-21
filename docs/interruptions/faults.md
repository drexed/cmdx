# Interruptions - Faults

Faults are exception mechanisms that halt task execution via `skip!` and `fail!` methods. When tasks execute with the `execute!` method, fault exceptions matching the task's interruption status are raised, enabling sophisticated exception handling and control flow patterns.

## Fault Types

| Type | Triggered By | Use Case |
|------|--------------|----------|
| `CMDx::Fault` | Base class | Catch-all for any interruption |
| `CMDx::SkipFault` | `skip!` method | Optional processing, early returns |
| `CMDx::FailFault` | `fail!` method | Validation errors, processing failures |

!!! warning "Important"

    All fault exceptions inherit from `CMDx::Fault` and provide access to the complete task execution context including result, task, context, and chain information.

## Fault Handling

```ruby
begin
  ProcessTicket.execute!(ticket_id: 456)
rescue CMDx::SkipFault => e
  logger.info "Ticket processing skipped: #{e.message}"
  schedule_retry(e.context.ticket_id)
rescue CMDx::FailFault => e
  logger.error "Ticket processing failed: #{e.message}"
  notify_admin(e.context.assigned_agent, e.result.metadata[:error_code])
rescue CMDx::Fault => e
  logger.warn "Ticket processing interrupted: #{e.message}"
  rollback_changes
end
```

## Data Access

Faults provide comprehensive access to execution context, eg:

```ruby
begin
  LicenseActivation.execute!(license_key: key, machine_id: machine)
rescue CMDx::Fault => e
  # Result information
  e.result.state     #=> "interrupted"
  e.result.status    #=> "failed" or "skipped"
  e.result.reason    #=> "License key already activated"

  # Task information
  e.task.class       #=> <LicenseActivation>
  e.task.id          #=> "abc123..."

  # Context data
  e.context.license_key #=> "ABC-123-DEF"
  e.context.machine_id  #=> "[FILTERED]"

  # Chain information
  e.chain.id         #=> "def456..."
  e.chain.size       #=> 3
end
```

## Advanced Matching

### Task-Specific Matching

Use `for?` to handle faults only from specific task classes, enabling targeted exception handling in complex workflows.

```ruby
begin
  DocumentWorkflow.execute!(document_data: data)
rescue CMDx::FailFault.for?(FormatValidator, ContentProcessor) => e
  # Handle only document-related failures
  retry_with_alternate_parser(e.context)
rescue CMDx::SkipFault.for?(VirusScanner, ContentFilter) => e
  # Handle security-related skips
  quarantine_for_review(e.context.document_id)
end
```

### Custom Logic Matching

```ruby
begin
  ReportGenerator.execute!(report: report_data)
rescue CMDx::Fault.matches? { |f| f.context.data_size > 10_000 } => e
  escalate_large_dataset_failure(e)
rescue CMDx::FailFault.matches? { |f| f.result.metadata[:attempt_count] > 3 } => e
  abandon_report_generation(e)
rescue CMDx::Fault.matches? { |f| f.result.metadata[:error_type] == "memory" } => e
  increase_memory_and_retry(e)
end
```

## Fault Propagation

Use `throw!` to propagate failures while preserving fault context and maintaining the error chain for debugging.

### Basic Propagation

```ruby
class ReportGenerator < CMDx::Task
  def work
    # Throw if skipped or failed
    validation_result = DataValidator.execute(context)
    throw!(validation_result)

    # Only throw if skipped
    check_permissions = CheckPermissions.execute(context)
    throw!(check_permissions) if check_permissions.skipped?

    # Only throw if failed
    data_result = DataProcessor.execute(context)
    throw!(data_result) if data_result.failed?

    # Continue processing
    generate_report
  end
end
```

### Additional Metadata

```ruby
class BatchProcessor < CMDx::Task
  def work
    step_result = FileValidation.execute(context)

    if step_result.failed?
      throw!(step_result, {
        batch_stage: "validation",
        can_retry: true,
        next_step: "file_repair"
      })
    end

    continue_batch
  end
end
```

## Chain Analysis

Results provide methods to analyze fault propagation and identify original failure sources in complex execution chains.

```ruby
result = DocumentWorkflow.execute(invalid_data)

if result.failed?
  # Trace the original failure
  original = result.caused_failure
  if original
    puts "Original failure: #{original.task.class.name}"
    puts "Reason: #{original.reason}"
  end

  # Find what propagated the failure
  thrower = result.threw_failure
  puts "Propagated by: #{thrower.task.class.name}" if thrower

  # Analyze failure type
  case
  when result.caused_failure?
    puts "This task was the original source"
  when result.threw_failure?
    puts "This task propagated a failure"
  when result.thrown_failure?
    puts "This task failed due to propagation"
  end
end
```

---

- **Prev:** [Interruptions - Halt](halt.md)
- **Next:** [Interruptions - Exceptions](exceptions.md)
