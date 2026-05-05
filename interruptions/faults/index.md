# Interruptions - Faults

`CMDx::Fault` is the exception `execute!` raises on failure. Skipped and successful results never raise. A Fault wraps the **originating** failed `Result` — the leaf at the bottom of any propagation chain — and delegates `task`, `context`, and `chain` to it. See [Exceptions](https://drexed.github.io/cmdx/interruptions/exceptions/index.md) for the full hierarchy.

## What's on a Fault

| Accessor          | Returns             | Notes                                                                                                                                                                            |
| ----------------- | ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `fault.result`    | `CMDx::Result`      | The failed result that originated the failure (after walking `origin`)                                                                                                           |
| `fault.task`      | `Class<CMDx::Task>` | The failing task **class** (`fault.result.task`)                                                                                                                                 |
| `fault.context`   | `CMDx::Context`     | The failing task's frozen context                                                                                                                                                |
| `fault.chain`     | `CMDx::Chain`       | The chain of every result produced during the run                                                                                                                                |
| `fault.message`   | `String`            | `I18nProxy.tr(result.reason)` — translates when the reason is an i18n key, otherwise passes through; falls back to the localized `cmdx.reasons.unspecified` when reason is `nil` |
| `fault.backtrace` | `Array<String>`     | From `result.backtrace` or `result.cause&.backtrace_locations`, cleaned via `task.settings.backtrace_cleaner` when configured                                                    |

Use `fault.result` to read the failed outcome's `reason`, `metadata`, `cause`, `origin`, `state`, and `status`.

Note

`Fault` wraps failures originating from `fail!`, `throw!`, or explicit `errors.add`. When Runtime rescued an ordinary `StandardError` (so `result.cause` is a non-`Fault`), `execute!` re-raises that **original** exception instead of wrapping it. For workflows, `fault.task` always points at the leaf that failed — not the workflow class — so matchers like `Fault.for?(LeafTask)` work the same in flat and nested executions.

## Fault Handling

```ruby
begin
  ProcessTicket.execute!(ticket_id: 456)
rescue CMDx::Fault => e
  logger.error "Ticket processing failed: #{e.message}"
  logger.info  "Failing task: #{e.task}"
  notify_admin(e.result.metadata[:error_code])
end
```

When you need to keep working with the result rather than rescuing, use `execute` and inspect it directly:

```ruby
result = ProcessTicket.execute(ticket_id: 456)

result.on(:failed) do |r|
  logger.error "Ticket processing failed: #{r.reason}"
  notify_admin(r.metadata[:error_code], context: r.context)
end
```

Either form gives you the same data: with `execute!`, reach for `fault.result` / `fault.context` / `fault.chain`; with `execute`, work with the returned `result` directly.

## Advanced Matching

### Task-Specific Matching

`Fault.for?(*task_classes)` returns an anonymous matcher subclass suitable for `rescue`. It matches any fault whose `task` is (or inherits from) one of the given classes:

```ruby
begin
  DocumentWorkflow.execute!(document_data: data)
rescue CMDx::Fault.for?(FormatValidator, ContentProcessor) => e
  # Handle only document-related failures
  retry_with_alternate_parser(e.result.metadata)
end
```

### Reason-Specific Matching

`Fault.reason?(reason)` returns an anonymous matcher subclass that matches any fault whose `result.reason` equals the given string:

```ruby
begin
  ProcessPayment.execute!(payment_data: data)
rescue CMDx::Fault.reason?("Payment declined") => e
  notify_customer(e.context.customer_id)
end
```

### Custom Logic Matching

`Fault.matches?` takes a block returning `true`/`false` against the fault. Use it for arbitrary predicates — metadata, status, cause class, etc.:

```ruby
begin
  ReportGenerator.execute!(report: report_data)
rescue CMDx::Fault.matches? { |f| f.result.metadata[:attempt_count].to_i > 3 } => e
  abandon_report_generation(e)
rescue CMDx::Fault.matches? { |f| f.result.metadata[:error_type] == "memory" } => e
  increase_memory_and_retry(e)
end
```

Note

Each call to `for?` / `matches?` returns a fresh anonymous matcher subclass, so they can be stacked across multiple `rescue` clauses but cannot be combined into a single matcher.

## Fault Propagation

Use `throw!` to re-raise an upstream failed result through the current task. The propagated signal mirrors the original's state, status, and reason and attaches the current `caller_locations` as the backtrace. It's a no-op when the argument isn't `failed?` — skipped or successful results are never converted into failures.

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

Pass keyword args to attach extra metadata to the propagated signal:

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

`Fault` exposes the originating `Result` via `fault.result`, plus the full `chain` it belongs to. From either, you can walk failure propagation with `origin`, `caused_failure`, and `threw_failure`. See [Result - Chain Analysis](https://drexed.github.io/cmdx/outcomes/result/#chain-analysis) for the full API.

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
