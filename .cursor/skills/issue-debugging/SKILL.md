---
name: issue-debugging
description: Systematically diagnose and resolve bugs, errors, and unexpected behavior in CMDx tasks, workflows, context, and runtime execution. Use when the user mentions a bug, error, unexpected result, failing test, exception, stack trace, wrong state, wrong status, nil value, or debugging. Don't use for feature additions, performance tuning, or test-only changes.
---

# Issue Debugging

> **Scope check:** Clarify the symptom, reproduction steps, and expected vs actual behavior with the user before diving into code.

## Prerequisites

Ensure the test suite and linter are runnable:

```bash
bundle exec rspec .
bundle exec rubocop .
```

## Procedures

**Step 0: Gather Context**

Before touching code, collect everything available:

1. **Symptoms** — exact error message, stack trace, wrong state/status, unexpected nil. Note **frequency**: always, intermittent, or flaky.
2. **Expected vs actual** — what should happen, what does happen.
3. **Reproduction path** — exact input hash, task class, `execute` vs `execute!`, context shape.
4. **Environment** — Ruby version, YJIT on/off, gem versions, OS.
5. **Recency** — when did it start? Correlate with recent commits, dependency updates, or Ruby upgrades.

**Step 1: Reproduce the Issue**

Never debug what you can't reproduce. Establish a reliable reproduction first.

1. Write the smallest possible reproduction case.
2. Confirm the reproduction fails consistently. If the issue is intermittent, note the conditions (input shape, context state, Ruby version, YJIT on/off).
3. If a failing spec already exists, skip the script and use the spec directly.
4. **Differential debugging** — if the same code works in one context but not another, compare the two. The delta is the clue.
5. **If not reproducible** — the bug is likely environment-specific, data-dependent, or timing-dependent:
   - Check for context state that differs between runs.
   - Check for frozen object mutations that only trigger under certain execution orders.

**Step 2: Classify the Bug**

Determine which category the issue falls into — this guides where to look:

| Category | Symptoms | Start Looking At |
|---|---|---|
| **Signal/Flow** | Wrong `state` or `status` on result; `success!`/`skip!`/`fail!` not halting | `lib/cmdx/task.rb` signal methods, `lib/cmdx/runtime.rb` `catch`/`throw` |
| **Context** | `nil` values, missing keys, wrong types, frozen context mutation | `lib/cmdx/context.rb` `method_missing`, `build`, `merge`, `freeze` |
| **Fault propagation** | Exception not caught, wrong fault type rescued, `execute!` vs `execute` mismatch | `lib/cmdx/exceptions.rb`, `lib/cmdx/runtime.rb` rescue chain |
| **Result** | Incorrect `reason`, `metadata`, `cause`; pattern match failures | `lib/cmdx/result.rb`, `lib/cmdx/signal.rb` |
| **Workflow** | Tasks execute in wrong order, breakpoints ignored, conditionals misfire | Workflow runner, task ordering logic |
| **Integration** | Works in isolation, fails when composed; context bleeds between tasks | Context sharing via `Context.build` passthrough, frozen state |

**Step 3: Isolate the Failure**

Narrow the search space systematically. **Mark each finding as verified or inferred** — don't let assumptions compound.

1. **Read the stack trace top-to-bottom.** The exception origin is usually in app code, not framework internals. Identify the first app-level frame.
2. **Map the execution path.** Trace the chain: task entry → context build → `work` → signal/exception → runtime catch → result. Identify where data goes wrong.
3. **Binary search the code.** Comment out half the logic, see if the bug persists, repeat.
4. **Binary search the history.** If the bug is a regression, use `git bisect` to pinpoint the introducing commit. If bisect lands on a large commit, narrow further by inspecting the diff file-by-file.

**Step 4: Diagnose Root Cause**

Identify **why** the bug exists, not just **where**. Use evidence, not guesswork.

1. **Form ranked hypotheses** — list candidate causes ordered by likelihood. Design **small experiments** (one variable at a time) to falsify each.
2. **Collect evidence** — trace output, result inspection, `pp` in console. **Verify** actual values at each step; don't assume what a variable holds.

Check these common root causes in priority order:

1. **Mismatched `execute` vs `execute!`** — `execute` swallows faults and returns a result; `execute!` re-raises as `SkipFault`/`FailFault`. Nested tasks using the wrong variant will silently swallow or unexpectedly raise.
2. **Signal already thrown** — calling `success!`/`skip!`/`fail!` after one was already thrown raises `"halt signal already thrown"`. Check for conditional branches that double-signal.
3. **Context frozen after `Result#freeze`** — `Result.new` calls `freeze`, which cascades to `Context#freeze` → `@table.freeze`. Tasks that mutate context after a result is generated will hit `FrozenError`.
4. **String key vs symbol key** — `Context` calls `transform_keys(&:to_sym)` on initialization. Passing string keys to `fetch` or `key?` without `.to_sym` returns `nil` or `false`.
5. **`method_missing` masking errors** — `Context#method_missing` returns `@table[method_name]` for any unknown method, which yields `nil`. A typo in a context accessor silently returns `nil` instead of raising.
6. **Fault `for?` / `matches?` not matching** — `Fault.for?` creates anonymous subclasses that use `===`; `rescue` clauses require `===` to match. Ensure the rescue variable is the fault instance, not the class.
7. **`throw!` propagating stale state** — `throw!` copies `state`, `status`, `reason`, and merges metadata from another result. If the source result is from a swallowed execution, its state may not reflect what you expect.

**Step 5: Implement the Fix**

1. **Fix the root cause, not the symptom.** Adding a nil guard is sometimes correct, but often masks the real bug upstream.
2. Write a **failing spec first** that captures the exact bug. Place it in the most relevant spec file under `spec/integration/`.
3. Apply the **minimum change** that resolves the issue. Resist refactoring adjacent code in the same fix.
4. **Check analogous code** — inspect sibling code paths (other task classes, similar runtime paths) for how they handle the same situation. Match established patterns unless the bug proves the pattern wrong.
5. **Search for related occurrences** — if the bug is a pattern (e.g., missing nil check on context access), search for the same pattern elsewhere: `rg "pattern" lib/`
6. Follow CMDx patterns:
   - Use `catch`/`throw` for flow control, never exceptions for non-error paths.
   - Keep signal construction in task private methods (`success!`, `skip!`, `fail!`, `throw!`).
   - Context mutations go through `store`/`merge`/`delete`, not direct `@table` access.
7. **Keep the fix isolated** — separate the bugfix commit from any refactoring.

**Step 6: Validate the Fix**

1. Run the full test suite: `bundle exec rspec .`
2. Run the linter: `bundle exec rubocop .`
3. Verify no collateral regressions by inspecting related specs (e.g., if you fixed a context bug, run all context-touching specs).
4. **Edge cases** — test nil, empty, frozen, and boundary scenarios related to the fix.

**Step 7: Guard Against Recurrence**

1. The failing spec from Step 5 is the regression guard. Ensure it covers the exact input that triggered the bug.
2. If the bug was caused by a subtle interaction (e.g., frozen context + nested tasks), add a comment explaining the constraint.
3. If the bug category appears in the anti-patterns table below, verify the broader codebase isn't affected.
4. **One-line root cause summary** — state what caused the bug in a single sentence for the commit message.

**Step 8: Document the Fix**

1. Add a `## Bug Fixes` entry to `CHANGELOG.md` describing what was broken and the root cause.
2. Update YARD docs if the fix changed method contracts or added constraints.
3. Correct any existing documentation that contradicts the fix.

## Debugging Principles

**Follow the data, not your assumptions.** Read actual values at each step. Use `pp`, `binding.break`, or other debugging tools. Don't assume what a variable holds.

**Reproduce before you fix.** A fix without reproduction is a guess. The reproduction spec proves the bug exists and proves the fix works.

**Simplify to isolate.** Remove variables until the bug disappears, then add back the last one — that's the cause.

**One change at a time.** When testing hypotheses, change one thing, verify, then move on. Multiple simultaneous changes make it impossible to know what worked.

**Check the boundaries.** Most bugs live at the interface between two components — context passing, signal propagation, `execute` vs `execute!`, frozen vs mutable state.

**Don't cargo-cult fixes.** If you don't understand why a fix works, you don't have a fix — you have a coincidence. Understand the root cause.

## Common Anti-Patterns

| Anti-Pattern | Why It Causes Bugs | Fix |
|---|---|---|
| Fixing without reproducing | You're guessing; the bug may persist or recur | Write a failing spec first |
| Fixing the symptom, not the cause | Bug recurs in a different form | Trace to root cause |
| Adding nil guards everywhere | Masks upstream bugs, creates silent data loss | Fix the source of the nil |
| Changing multiple things at once | Can't tell which change fixed it | One hypothesis at a time |
| Leaving debug code in | `binding.break`, `pp` in committed code | Remove before committing |
| Rescuing `StandardError` broadly | Swallows `Fault` subclasses that should propagate | Rescue specific exception classes; let `Fault` flow through `catch`/`throw` |
| Mutating context after `freeze` | `Result.new` freezes the context; later writes raise `FrozenError` | Complete all context mutations before signaling |
| Using `execute!` in workflow steps | One failed inner task aborts the entire workflow via exception | Use `execute` + inspect result, or `throw!` to propagate signals |
| Double-signaling in branching logic | `"halt signal already thrown"` error | Ensure only one of `success!`/`skip!`/`fail!` is reachable per execution path |
| Comparing result with `==` | `Result` is frozen and doesn't define `==` | Use `have_attributes` matcher or check individual fields |
| String keys in context lookups | `Context` symbolizes keys on init; string lookups return `nil` | Always use symbol keys: `ctx[:foo]`, not `ctx["foo"]` |
| Relying on `method_missing` return for presence | Returns `nil` for missing keys, not `KeyError` | Use `ctx.key?(:foo)` or `ctx.fetch(:foo)` for presence checks |
| Catching `:cmdx` tag outside runtime | Interferes with `Signal::TAG` flow | Never use `catch(:cmdx)` outside of `Runtime#execute_work` |

## Decision Tree

When the bug doesn't fit neatly into the classification table, follow this tree:

1. **Is there an exception/stack trace?**
   - Yes → Read the backtrace bottom-up. Find the first CMDx frame. That's your entry point.
   - No → Go to 2.
2. **Is the result in an unexpected state/status?**
   - Yes → Trace signal construction. Check which of `success!`/`skip!`/`fail!`/`throw!` was called, or if `catch` fell through to `Signal::Success`.
   - No → Go to 3.
3. **Is context data wrong or missing?**
   - Yes → Trace context mutations. Check `Context.build` passthrough, `method_missing` typos, freeze timing.
   - No → Go to 4.
4. **Does the bug only appear in composition (workflows/nested tasks)?**
   - Yes → Check `execute` vs `execute!` usage, `throw!` propagation, context sharing between tasks.
   - No → Collect more information; the reproduction may be incomplete.

## Error Handling

- If a fix introduces new test failures, the fix is incomplete — it changed behavior that other code depends on. Understand the dependency before adjusting.
- If the bug is not reproducible outside of a specific Ruby version, check for VM-specific behavior (frozen string interning, `method_missing` dispatch changes, YJIT deoptimizations).
- If `git bisect` points to a large commit, narrow further by inspecting the diff file-by-file and testing each changed file's effect in isolation.
- If the bug is in a third-party gem, verify with the library's changelog and issue tracker before patching locally. Prefer upgrading over monkey-patching.

## Final Validation

Cross-reference the completed fix against `references/checklist.md`.
