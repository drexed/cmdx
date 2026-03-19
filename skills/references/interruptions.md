# Interruptions Reference

For full documentation, see [docs/interruptions/halt.md](../docs/interruptions/halt.md), [docs/interruptions/faults.md](../docs/interruptions/faults.md), [docs/interruptions/exceptions.md](../docs/interruptions/exceptions.md).

## success!

Annotates a successful result with a reason and metadata. Does not change state or status. Delegated from the task to the result.

```ruby
success!(reason = nil, **metadata)
```

| Param | Default | Effect |
|-------|---------|--------|
| `reason` | `nil` | Human-readable annotation string |
| `**metadata` | `{}` | Arbitrary key-value pairs stored in `result.metadata` |

Raises `RuntimeError` if the result is not currently `success`.

## skip! and fail!

Both are delegated from the task to the result. Callable inside `work`, callbacks, or anywhere with access to the task/result.

```ruby
skip!(reason = nil, halt: true, cause: nil, **metadata)
fail!(reason = nil, halt: true, cause: nil, **metadata)
```

| Param | Default | Effect |
|-------|---------|--------|
| `reason` | `"Unspecified"` | Human-readable reason string |
| `halt` | `true` | When true, raises `SkipFault`/`FailFault` to stop execution |
| `cause` | `nil` | Originating exception |
| `**metadata` | `{}` | Arbitrary key-value pairs stored in `result.metadata` |

### State transitions

| Method | State | Status | `good?` | `bad?` |
|--------|-------|--------|---------|--------|
| `skip!` | `interrupted` | `skipped` | `true` | `true` |
| `fail!` | `interrupted` | `failed` | `false` | `true` |

### Idempotency

Calling `skip!` when already skipped (or `fail!` when already failed) is a no-op. But `skip!` after `fail!` (or vice versa) raises `RuntimeError` — status transitions are one-way from `success`.

### halt: false

Continue execution after setting status:

```ruby
def work
  fail!("Missing field", halt: false, field: :email)
  # execution continues — useful for collecting multiple issues
  fail!("Missing field", halt: false, field: :name)
  # second fail! is a no-op since already failed
end
```

### Metadata enrichment

```ruby
fail!("License not eligible", error_code: "LICENSE.NOT_ELIGIBLE", retry_after: 30.days.from_now)
skip!("Already processed", processed_at: record.processed_at)

# Access later
result.metadata[:error_code]     #=> "LICENSE.NOT_ELIGIBLE"
result.metadata[:retry_after]    #=> <Time>
```

## throw!

Propagates another task's result upward, copying state, status, reason, cause, and metadata:

```ruby
throw!(result, halt: true, cause: nil, **metadata)
```

```ruby
def work
  inner = InnerTask.execute(context)

  # Throw on any non-success (copies status from inner result)
  throw!(inner) unless inner.success?

  # Throw only on failure
  throw!(inner) if inner.failed?

  # Throw with additional metadata
  throw!(inner, stage: "validation", can_retry: true) if inner.failed?

  # Throw without halting (rare)
  throw!(inner, halt: false) if inner.failed?
end
```

Throwing a successful result copies the success state and does not raise (since `halt!` is a no-op on success).

## Nested Task Propagation Strategies

Three patterns for calling tasks from within other tasks:

### Swallow (silent)

```ruby
def work
  InnerTask.execute(context)
  # Inner failure is ignored — outer task continues and succeeds
  # Inner result is still in the chain but doesn't affect outer
end
```

Use when the inner task is optional and its failure should not affect the caller.

### Throw (propagate result)

```ruby
def work
  inner = InnerTask.execute(context)
  throw!(inner) unless inner.success?
  # Copies inner's state/status/reason/metadata to this task's result
  # Raises SkipFault or FailFault (halt: true by default)
end
```

Use when you want to propagate the inner result with full control over when to propagate. The outer result preserves the inner's reason and metadata. Chain analysis tracks both `caused_failure` (inner) and `threw_failure` (outer).

### Raise (bang execution)

```ruby
def work
  InnerTask.execute!(context)
  # Raises FailFault/SkipFault if inner task fails/skips
  # Exception propagates up — must be caught by caller or Executor
end
```

Use when inner failure should immediately halt the caller. The exception bypasses `throw!` — the outer task's result is set by the Executor's rescue handler.

### Strategy comparison

| Strategy | Inner fails | Outer continues? | Chain tracks cause? | Metadata preserved? |
|----------|------------|-------------------|---------------------|---------------------|
| Swallow | `execute` | Yes | No | No |
| Throw | `execute` + `throw!` | No | Yes (`caused_failure` + `threw_failure`) | Yes |
| Raise | `execute!` | No | Partial | Via exception |

### Nesting multiple levels

```ruby
# OuterTask → MiddleTask → InnerTask
# Each level chooses its own strategy independently

class MiddleTask < CMDx::Task
  def work
    inner = InnerTask.execute(context)
    throw!(inner) unless inner.success?   # throw strategy
    (context.executed ||= []) << :middle
  end
end

class OuterTask < CMDx::Task
  def work
    middle = MiddleTask.execute(context)
    throw!(middle) unless middle.success?  # throw strategy
    (context.executed ||= []) << :outer
  end
end
```

## Fault Matching

`for?` and `matches?` are **class methods** on `Fault` (and `SkipFault`/`FailFault`) that return matcher classes for use in `rescue`:

### Task-specific matching

```ruby
begin
  Workflow.execute!(data: input)
rescue CMDx::FailFault.for?(PaymentTask, BillingTask) => e
  handle_payment_failure(e)
rescue CMDx::SkipFault.for?(AuditTask) => e
  log_audit_skip(e)
rescue CMDx::Fault => e
  handle_generic_fault(e)
end
```

### Custom logic matching

```ruby
begin
  Workflow.execute!(data: input)
rescue CMDx::FailFault.matches? { |f| f.result.metadata[:critical] } => e
  escalate(e)
rescue CMDx::Fault.matches? { |f| f.result.metadata[:retryable] } => e
  schedule_retry(e)
end
```

### Fault data access

```ruby
rescue CMDx::Fault => e
  e.result         # CMDx::Result
  e.task           # CMDx::Task instance (delegated from result)
  e.context        # CMDx::Context (delegated from result)
  e.chain          # CMDx::Chain (delegated from result)
  e.message        # reason string (set from result.reason)
  e.result.reason  # same reason
  e.result.status  # "failed" or "skipped"
  e.result.metadata # metadata hash
end
```

## Manual Errors

Add errors before halting for structured validation messages:

```ruby
def work
  errors.add(:email, "is invalid")
  errors.add(:email, "is required")
  errors.add(:name, "is too short")
  fail!("Validation failed")
end
```

### Errors API

```ruby
errors.add(:attr, "message")    # add error
errors.any?                     # true if errors exist
errors.empty?                   # true if no errors
errors.size                     # number of attributes with errors
errors.for?(:attr)              # true if attr has errors
errors.to_h                     # { attr: ["msg1", "msg2"] }
errors.full_messages            # { attr: ["attr msg1", "attr msg2"] }
errors.to_s                     # "attr msg1. attr msg2"
errors.clear                    # remove all errors
```

## Exception Hierarchy

```
StandardError
└── CMDx::Error
    ├── CMDx::CoercionError       # type coercion failed
    ├── CMDx::DeprecationError    # deprecated task used with :raise
    ├── CMDx::UndefinedMethodError # missing work method
    ├── CMDx::ValidationError     # validation failed
    └── CMDx::Fault               # base for skip/fail faults
        ├── CMDx::SkipFault       # raised by skip! + halt
        └── CMDx::FailFault       # raised by fail! + halt

Interrupt
└── CMDx::TimeoutError            # always raised, NOT caught by rescue StandardError
```

`execute` catches `StandardError` and converts to failed results. `CMDx::TimeoutError` inherits from `Interrupt` and always propagates.
