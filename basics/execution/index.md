# Basics - Execution

CMDx offers two execution methods with different error handling approaches. Choose based on your needs: safe result handling or exception-based control flow.

## Execution Methods

Both methods return results, but handle failures differently:

| Method     | Returns                                     | Exceptions                                                                                                                                                                                            | Use Case                                             |
| ---------- | ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| `execute`  | Returns `CMDx::Result` for any task outcome | Never raises for ordinary failures; framework errors (`CMDx::Error` subclasses like `ImplementationError`, `MiddlewareError`, `CallbackError`, `DefinitionError`, `DeprecationError`) still propagate | Branch on `result.success?` / `failed?` / `skipped?` |
| `execute!` | Returns `CMDx::Result` on success or skip   | Raises `CMDx::Fault` on failed outcomes, or the underlying exception when `work` raised a non-`Fault` `StandardError`                                                                                 | Exception-based control flow                         |

`call` / `call!` are aliases. `execute` / `execute!` also accept a block — when given, the block receives the `Result` and its return value is returned instead of the result.

Both class-level entry points forward to `Task#execute(strict:)`, which is also public — useful when you already have a task instance:

```ruby
task   = CreateAccount.new(email: "user@example.com")
result = task.execute              # strict: false → returns Result
task.execute(strict: true)         # strict: true  → raises Fault on failure
```

```
flowchart LR
    subgraph Methods
        E[execute]
        EB[execute!]
    end

    subgraph Returns [Returns CMDx::Result]
        Success
        Failed
        Skipped
    end

    subgraph Raises [Raises CMDx::Fault]
        Fault
    end

    E --> Success
    E --> Failed
    E --> Skipped

    EB --> Success
    EB --> Skipped
    EB --> Fault
```

`Skipped` is **not** a failure — `execute!` returns the skipped `Result` rather than raising. Only `failed?` results raise.

## Non-bang Execution

Returns a `CMDx::Result` for every task outcome (success, skip, fail). Default choice for most call sites. Framework errors (`CMDx::Error` subclasses) still propagate — they signal misconfiguration that should never be silently swallowed.

```ruby
result = CreateAccount.execute(email: "user@example.com")
result.context.email #=> "user@example.com"

# Block form — returns whatever the block returns
CreateAccount.execute(email: "user@example.com") do |result|
  result.success? ? result.context.account_id : nil
end
```

## Bang Execution

Raises `CMDx::Fault` on failure (or the originating `StandardError` if one was captured as the cause). Returns the result on success or skip.

```ruby
begin
  result = CreateAccount.execute!(email: "user@example.com")
  SendWelcomeEmail.execute(result.context)
rescue CMDx::Fault => e
  Rails.logger.warn("#{e.task} failed: #{e.message}")
  ScheduleAccountRetryJob.perform_later(email: "user@example.com")
rescue StandardError => e
  ErrorTracker.capture(unhandled_exception: e)
end
```

Strict re-raise order

When `work` raises a non-framework `StandardError`, Runtime captures it on `result.cause` **and** re-raises the **original** exception under strict mode — not a `Fault`. Put `rescue CMDx::Fault` before `rescue StandardError` (Fault is a `StandardError` subclass). A `fail!` / `throw!` / validation / output failure has no captured `cause`, so it raises `Fault` carrying the caused-failure leaf as `fault.result`.

Teardown ordering

Result finalization runs **before** the strict re-raise, and teardown (freeze + chain clear) runs in an `ensure` after. This means `fault.result`, `fault.context`, and `fault.chain` are all safe to read inside any `rescue` — and a lifecycle log line / `:task_executed` telemetry event still fires on strict failures.
