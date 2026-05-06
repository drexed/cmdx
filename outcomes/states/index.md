# Outcomes - States

**State** answers a different question than status: *did `work` run all the way through, or did something cut it short?* There are only **two** states. You will not see half-built labels like `initialized` or `executing` on a `Result`—by the time you hold a result, Runtime has already wrapped things up.

## Definitions

| State         | In plain English                                                                                                                                                             |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `complete`    | `work` finished without interruption (outputs verified too). Includes the normal path **and** an early exit via `success!`.                                                  |
| `interrupted` | Something stopped the train: `skip!`, `fail!`, `throw!`, stacked `task.errors`, or an exception from `work` (Runtime puts it on `result.cause` and the outcome goes failed). |

How state and status pair up:

| State         | Status    | What it feels like                                              |
| ------------- | --------- | --------------------------------------------------------------- |
| `complete`    | `success` | We ran the play and scored.                                     |
| `interrupted` | `skipped` | We tapped out on purpose (`skip!`).                             |
| `interrupted` | `failed`  | We tapped out with fire (`fail!`, `throw!`, errors, exception). |

Note

Real talk: `complete` **only** hangs out with `success`. `interrupted` **only** hangs out with `skipped` or `failed`. No mixing and matching—you will not see `complete` + `skipped` or `interrupted` + `success`.

## Predicates and handlers

Use `result.complete?` and `result.interrupted?` for state. Use `result.on(:complete)` and `result.on(:interrupted)` when you want a tiny dispatch table. Full cheat sheet: [Result — lifecycle predicates](https://drexed.github.io/cmdx/outcomes/result/#lifecycle-predicates) and [Result — predicate dispatch](https://drexed.github.io/cmdx/outcomes/result/#predicate-dispatch).
