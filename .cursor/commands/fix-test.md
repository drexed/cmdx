# Fix Test

## Role

You are a senior developer diagnosing failing specs — verifying source code correctness first, then adjusting specs only when the implementation is confirmed correct.

## Context

Failing specs indicate either a bug in the source code or an outdated/incorrect spec. The correct response depends on which side is wrong:

| Verdict | Action |
|---|---|
| **Source is wrong** | Fix the source code; leave the spec as-is (it's the regression guard) |
| **Spec is wrong** | Fix the spec to match the confirmed-correct implementation |
| **Both are wrong** | Fix the source first, then update the spec |

This project uses RSpec with FactoryBot, CMDx tasks, Sidekiq jobs, and Phlex views. Specs live under `spec/` and mirror `app/` structure. Run specs with `bundle exec rspec <file>:<line>`.

### Decision Priority

1. **Specs are the contract.** If the spec describes the intended behavior and the source deviates, the source has a bug — fix the source.
2. **Implementation wins only when confirmed.** If you can verify (via commit history, surrounding code, domain logic, or user confirmation) that the current implementation is intentionally correct and the spec is stale, update the spec.
3. **When in doubt, ask.** If intent is ambiguous, present both interpretations and let the user decide.

## Task

Diagnose why specs are failing, determine whether the source or the specs are at fault, and apply the correct fix.

### Steps

1. **Identify failing specs** — Ask the user for:
   - **Spec file or pattern** — path to the failing spec file, directory, or a `bundle exec rspec` command with output. If the user provides test output, extract file paths and line numbers.
   - **Scope** — fix all failures in the file (default) or only specific examples (user can specify line numbers).
   - **Recent changes** — what changed that may have caused the failure (refactor, new feature, dependency update). This guides drift detection.

2. **Check prior knowledge** — Before diving into code, query **mcp-knowledge-graph** (`search_nodes` / `read_graph`) for known blockers, handoff notes, or related issues. If the failure matches a known issue, follow the documented resolution path.

3. **Run the failing specs** — Execute the specs to capture current failures:
   ```bash
   bundle exec rspec <file>:<line> --format documentation --no-color 2>&1
   ```
   - Record each failure: example name, file:line, error class, message, and the first app-level stack frame.
   - If all specs pass, report that and stop.

4. **Detect code drift** — Run these in parallel:
   ```bash
   git diff --name-only
   git diff --cached --name-only
   ```
   - For each changed source file, locate its corresponding spec file(s).
   - Read both the source and spec side-by-side and flag **drift**:
     - Renamed methods, classes, modules, or constants not reflected in specs
     - Changed method signatures (added/removed/reordered params) with specs still using old signatures
     - Modified return values, error types, or side effects that specs still assert on old behavior
     - New validations, callbacks, or guards added to source with no spec coverage
     - Removed or restructured code paths that specs still reference
   - If no modified files relate to the failures, skip to the next step.

5. **Read source and spec code** — For each failure, run these in parallel:
   - Read the **spec file** — understand what the test expects (setup, action, assertion).
   - Read the **source file** under test — understand the actual implementation.
   - Read **related files** if needed (factories, shared examples, concerns, serializers, sibling specs).

6. **Diagnose each failure** — For each failing example:
   - **Map the assertion gap** — what does the spec expect vs what does the source produce? Identify the exact divergence point.
   - **Trace the root cause** — is the divergence in the source logic, the test setup, the factory data, a missing stub, a timing issue, or a changed dependency?
   - **Classify the verdict:**
     - **Source bug** — the spec describes correct behavior; the source has a defect. Evidence: the spec matches the domain contract, related specs rely on the same behavior, commit history shows an unintended change.
     - **Spec bug** — the implementation is intentionally correct; the spec is stale or wrong. Evidence: recent intentional refactor changed the interface, spec tests an outdated API, factory produces invalid state.
     - **Drift** — source was intentionally changed but the spec was not updated to match. A subtype of spec bug with clear causal evidence from the git diff.
     - **Setup bug** — the spec logic is correct but the test arrangement is wrong (bad factory data, missing stub, wrong context). Fix the setup, not the assertion.
     - **Ambiguous** — cannot determine intent from code alone. Escalate to the user.

7. **Present findings** — Before writing any code, summarize all diagnoses at once:
   - Root cause per failure, whether the bug is in source or spec, and the proposed fix.
   - If drift was detected, list each drifted spec with what changed in source and what the spec still expects.
   - **Wait for user confirmation** before proceeding to fixes. If multiple failures exist, present the full diagnosis table for all of them.

8. **Fix — source-first, one at a time** — With user approval, apply fixes per verdict:
   - **If source bug:** Read the relevant skill for the source file's layer (model-patterns, task-patterns, etc.). Fix the source code. Do **not** touch the spec. Re-run the spec to confirm it passes before moving to the next failure.
   - **If spec bug / drift:** Read `test-patterns/SKILL.md` and the relevant category reference. Update the spec to match the confirmed-correct implementation. Explain why the spec was wrong. Re-run to confirm green before moving on.
   - **If setup bug:** Fix only the test setup (factory, let blocks, stubs, context). Do not change assertions or source code. Re-run to confirm.
   - **If ambiguous:** Present both interpretations with evidence. Ask the user which is correct before making changes.
   - Fix one failure at a time; re-run between each fix to isolate regressions.

9. **Verify clean state** — After all fixes are applied:
   ```bash
   bundle exec rspec <file> --format documentation --no-color 2>&1
   ```
   - All previously failing examples must now pass.
   - No previously passing examples should break (run the full spec file, not just the failing lines).
   - **If new failures appear**, diagnose them — the fix may be incomplete or may have changed behavior that other examples depend on.

10. **Lint** — Run linters on all modified files:
    ```bash
    bundle exec rubocop
    ```
    - Fix any lint errors introduced by the changes.

11. **Report** — Display the result.

## Constraints

- Do **not** modify specs when the source code has the bug — fix the source first
- Do **not** weaken or delete assertions to make tests pass — if an assertion fails, either the source or the setup needs fixing
- Do **not** add `skip`, `pending`, or `xit` to bypass failures
- Do **not** modify files outside the scope of the failing specs unless the root cause is in a shared dependency
- Do **not** change factory definitions without verifying that other specs using the same factory still pass
- Do **not** fabricate test data or stub behavior that masks the real issue
- Do **not** modify `git config`, force-push, or skip hooks
- Do **not** write any code before presenting findings and receiving user approval
- Fix one failure at a time — re-run between each fix to isolate regressions
- If intent is unclear, **ask the user** — never guess which side is correct
- Read the relevant pattern skill before editing any source or spec file

## Output

After resolving, display:

| Field | Value |
|---|---|
| **Spec File** | `<path>` |
| **Failures** | `<count> failing → <count> fixed` |
| **Status** | All passing / Partial / Needs user input |

Then list each addressed failure:

| # | Example | Verdict | Fix Applied | File Changed |
|---|---------|---------|-------------|--------------|
| 1 | `example description` | Source bug / Spec bug / Drift / Setup bug | `<brief description>` | `<path>` |
| 2 | … | … | … | … |
