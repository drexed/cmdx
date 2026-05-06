# Outcomes - Statuses

**Status** answers the question everyone cares about first: *did this task win, bail out gracefully, or blow up?* It is all about the **business outcome**. It does not tell you whether the lifecycle ran start-to-finish—that job belongs to [state](https://drexed.github.io/cmdx/outcomes/states/index.md).

## Definitions

Think of status as the label on your report card:

| Status    | In plain English                                                                                                                              |
| --------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `success` | `work` finished happily (outputs checked out too), or you stopped early with `success!`. This is the happy path most of the time.             |
| `skipped` | You called `skip!`. Nothing crashed—it is just “we are not doing this.” Still counts as a non-failure.                                        |
| `failed`  | You called `fail!` or `throw!`, errors piled up on the task, or `work` raised a normal Ruby exception (Runtime stashes it on `result.cause`). |

Note

`throw!` is special: it forwards another task’s already-failed result through yours. For the full story, see [Fault propagation](https://drexed.github.io/cmdx/interruptions/faults/#fault-propagation).

## One shot, one status

Statuses do not morph over time. The moment `skip!` or `fail!` runs inside `work`, execution unwinds and the result is built **once** with a single final status:

```ruby
def work
  fail!("first")    # Runtime catches this and finalizes the result
  skip!("second")   # Unreachable—game over after fail!
end
```

Note

If you try `skip!` or `fail!` after Runtime has torn everything down (frozen task), you get `FrozenError`. The story is already written—you cannot rewrite it.

## Predicates and handlers

- `result.success?`, `result.skipped?`, `result.failed?` mirror those three labels.
- `result.ok?` means success **or** skipped (fine enough to move on).
- `result.ko?` means skipped **or** failed (work did not fully succeed).

Hook them up with `result.on(:success | :skipped | :failed | :ok | :ko)`. More detail lives in [Result — lifecycle predicates](https://drexed.github.io/cmdx/outcomes/result/#lifecycle-predicates) and [Result — predicate dispatch](https://drexed.github.io/cmdx/outcomes/result/#predicate-dispatch).

Note

`skipped` is the quirky one: it is both `ok?` and `ko?`. Valid outcome (`ok`) but not the gold star (`ko`). When you truly need “we shipped it,” use `success?`.
