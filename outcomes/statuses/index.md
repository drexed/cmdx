# Outcomes - Statuses

Statuses represent the business outcome — did the task succeed, skip, or fail? This is independent of state, which only tracks whether the lifecycle ran to completion or was interrupted.

## Definitions

| Status    | Description                                                                                                                                    |
| --------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `success` | Task `work` ran to completion (and any declared outputs verified), or halted via `success!`. Default outcome.                                  |
| `skipped` | Task halted via `skip!`. Treated as a non-failure outcome.                                                                                     |
| `failed`  | Task halted via `fail!`, `throw!`, accumulated `task.errors`, or a `StandardError` raised from `work` (Runtime captures it on `result.cause`). |

Note

`throw!` isn't a primitive halt — it re-throws a peer's already-`failed?` result through the current task. See [Fault Propagation](https://drexed.github.io/cmdx/interruptions/faults/#fault-propagation).

## Single Final Status

Statuses don't transition. The first `skip!` / `fail!` inside `work` throws out of the call stack, so the result is built once with a single, final status:

```ruby
def work
  fail!("first")    # Runtime catches this and finalizes the result
  skip!("second")   # Unreachable
end
```

Note

Calling `skip!` or `fail!` on a frozen task (after `Runtime` teardown) raises `FrozenError` — they can't mutate a finalized result.

## Predicates and Handlers

`result.success?` / `result.skipped?` / `result.failed?` check status; `result.ok?` (success or skipped) and `result.ko?` (skipped or failed) categorize the outcome. Dispatch with `result.on(:success | :skipped | :failed | :ok | :ko)`. See [Result - Lifecycle Predicates](https://drexed.github.io/cmdx/outcomes/result/#lifecycle-predicates) and [Result - Predicate Dispatch](https://drexed.github.io/cmdx/outcomes/result/#predicate-dispatch).

Note

`skipped` is intentionally both `ok?` and `ko?`. It's a valid outcome (`ok` — nothing broke) and a non-success (`ko` — work wasn't done). Use `success?` when you need a strict success check.
