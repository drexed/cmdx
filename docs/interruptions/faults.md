# Interruptions - Faults

`CMDx::Fault` is the exception you get from `execute!` when a task fails. Skips and successes never become faults.

A fault wraps the **originating** failed `Result` — the leaf at the bottom of any `throw!` chain — and delegates `task`, `context`, and `chain` from that result. For the bigger picture on errors, see [Exceptions](exceptions.md).

## What's on a Fault

| Accessor | Returns | Notes |
|----------|---------|-------|
| `fault.result` | `CMDx::Result` | The failed result that started the problem (after walking `origin`) |
| `fault.task` | `Class<CMDx::Task>` | The failing task **class** (`fault.result.task`) |
| `fault.context` | `CMDx::Context` | The failing task's frozen context |
| `fault.chain` | `CMDx::Chain` | Every result produced during the run |
| `fault.message` | `String` | `I18nProxy.tr(result.reason)` — translates i18n keys, otherwise uses the string as-is; falls back to localized `cmdx.reasons.unspecified` when reason is `nil` |
| `fault.backtrace` | `Array<String>` | From `result.backtrace` or `result.cause&.backtrace_locations`, cleaned with `task.settings.backtrace_cleaner` when set |

For day-to-day debugging, read `fault.result` for `reason`, `metadata`, `cause`, `origin`, `state`, and `status`.

!!! note

    Faults cover failures from `fail!`, `throw!`, or `errors.add`. If the runtime rescued a plain `StandardError` and stored it on the result, `execute!` re-raises that original exception instead of a `Fault`. In workflows, `fault.task` always points at the leaf that failed, so `Fault.for?(LeafTask)` behaves the same for simple and nested runs.

## Fault Handling

Bang form: rescue and log or notify.

```ruby
begin
  ProcessTicket.execute!(ticket_id: 456)
rescue CMDx::Fault => e
  logger.error "Ticket processing failed: #{e.message}"
  logger.info  "Failing task: #{e.task}"
  notify_admin(e.result.metadata[:error_code])
end
```

Non-bang form: keep the `Result` and branch on it.

```ruby
result = ProcessTicket.execute(ticket_id: 456)

result.on(:failed) do |r|
  logger.error "Ticket processing failed: #{r.reason}"
  notify_admin(r.metadata[:error_code], context: r.context)
end
```

Same facts, two doors: `execute!` gives you `fault.result` / `fault.context` / `fault.chain`; `execute` gives you the `result` directly.

## Advanced Matching

### Task-Specific Matching

`Fault.for?(*task_classes)` builds a tiny matcher class you can use in `rescue`. It matches when `fault.task` is one of the listed classes (or inherits from one).

```ruby
begin
  DocumentWorkflow.execute!(document_data: data)
rescue CMDx::Fault.for?(FormatValidator, ContentProcessor) => e
  # Only document pipeline failures land here
  retry_with_alternate_parser(e.result.metadata)
end
```

### Reason-Specific Matching

`Fault.reason?(reason)` matches when `result.reason` equals the string you passed.

```ruby
begin
  ProcessPayment.execute!(payment_data: data)
rescue CMDx::Fault.reason?("Payment declined") => e
  notify_customer(e.context.customer_id)
end
```

### Custom Logic Matching

`Fault.matches?` runs your block on the fault. Use it for metadata, status, cause class, anything you can express in Ruby.

```ruby
begin
  ReportGenerator.execute!(report: report_data)
rescue CMDx::Fault.matches? { |f| f.result.metadata[:attempt_count].to_i > 3 } => e
  abandon_report_generation(e)
rescue CMDx::Fault.matches? { |f| f.result.metadata[:error_type] == "memory" } => e
  increase_memory_and_retry(e)
end
```

!!! note

    Each `for?` / `matches?` call returns a fresh anonymous class. Great for stacking `rescue` lines; not great for merging into one mega-matcher.

## Fault Propagation

`throw!` forwards another task's failed result through the current task. The signal copies state, status, and reason, and attaches the current `caller_locations` as the backtrace. If the argument is not failed, `throw!` does nothing — it never turns a skip or success into a failure.

### Basic Propagation

```ruby
class ReportGenerator < CMDx::Task
  def work
    # No-op when the upstream result wasn't failed
    throw!(DataValidator.execute(context))

    # Or guard explicitly
    perms = CheckPermissions.execute(context)
    throw!(perms) if perms.failed?

    generate_report
  end
end
```

### Additional Metadata

Keyword arguments merge into this task's result metadata on top of the propagated failure.

```ruby
class BatchProcessor < CMDx::Task
  def work
    step_result = FileValidation.execute(context)

    if step_result.failed?
      throw!(
        step_result,
        batch_stage: "validation",
        can_retry: true,
        next_step: "file_repair"
      )
    end

    continue_batch
  end
end
```

## Chain Analysis

`fault.result` is the originating failure; `fault.chain` is the whole story. Walk propagation with `origin`, `caused_failure`, and `threw_failure`. Full tour in [Result - Chain Analysis](../outcomes/result.md#chain-analysis).

```ruby
begin
  DocumentWorkflow.execute!(document_data: data)
rescue CMDx::Fault => e
  puts "Originated by #{e.task}: #{e.message}"
  puts "Root task: #{e.chain.first.task}"     # chain.first is always the root execution
end

# Or via non-bang execute:
result = DocumentWorkflow.execute(document_data: data)
if result.failed?
  origin = result.caused_failure
  puts "Originated by #{origin.task}: #{origin.reason}"
end
```
