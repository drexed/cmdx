# Outcomes - States

States track the lifecycle dimension of a result: did `work` run end-to-end, or did something interrupt it? There are exactly two states. Transient stages (`initialized`/`executing`) aren't modeled — `Result` is constructed once, after `Runtime` has finalized the task.

## Definitions

| State         | Description                                                                                                                                                                                |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `complete`    | Task finished `work` (and output verification) without interruption. Includes both the implicit success path and an explicit `success!` halt.                                              |
| `interrupted` | Task halted via `skip!`, `fail!`, `throw!`, accumulated `task.errors`, or a `StandardError` raised from `work` (Runtime captures it on `result.cause` and converts the outcome to failed). |

State-Status combinations:

| State         | Status    | Meaning                                                                        |
| ------------- | --------- | ------------------------------------------------------------------------------ |
| `complete`    | `success` | Task finished successfully                                                     |
| `interrupted` | `skipped` | Task halted via `skip!`                                                        |
| `interrupted` | `failed`  | Task halted via `fail!`, `throw!`, an exception, or validation/coercion errors |

Note

`complete` only ever pairs with `success`, and `interrupted` only ever pairs with `skipped` or `failed`. There is no `complete` + `skipped` or `interrupted` + `success` combination.

## Predicates and Handlers

`result.complete?` / `result.interrupted?` are the state predicates; `result.on(:complete)` / `result.on(:interrupted)` dispatch on them. See [Result - Lifecycle Predicates](https://drexed.github.io/cmdx/outcomes/result/#lifecycle-predicates) and [Result - Predicate Dispatch](https://drexed.github.io/cmdx/outcomes/result/#predicate-dispatch) for the canonical list.
