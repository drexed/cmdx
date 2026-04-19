# Issue Debugging Checklist

Final audit before merging a CMDx bug fix. Every item must pass.

## 0. Context & Reproduction

- [ ] **Bug Described:** The exact error message, wrong state/status, or unexpected behavior is documented.
- [ ] **Expected vs Actual:** Both are stated clearly.
- [ ] **Frequency Noted:** Always, intermittent, or flaky — and under what conditions.
- [ ] **Minimal Reproduction:** A standalone script or spec isolates the bug with the smallest possible input.
- [ ] **Consistently Reproducible:** The reproduction fails every time (or conditions for intermittent failure are noted).

## 1. Classification

- [ ] **Category Identified:** Bug is classified as signal/flow, context, fault propagation, result, workflow, or integration.
- [ ] **Root Cause Located:** The specific file, method, and line where the defect originates is identified.
- [ ] **Root Cause Verified:** The proposed cause actually explains the observed behavior (not just correlated).

## 2. Isolation

- [ ] **Fault Boundary Narrowed:** Binary search or tracing confirms exactly where behavior diverges from expectation.
- [ ] **Findings Labeled:** Each finding is marked as **verified** (observed) or **inferred** (hypothesized).
- [ ] **Related Code Inspected:** Sibling code paths (other tasks, similar runtime paths) checked for the same defect.
- [ ] **No Red Herrings:** Symptoms that looked related but aren't have been eliminated.

## 3. Fix Implementation

- [ ] **Root Cause Fixed:** The fix addresses the root cause, not the symptom.
- [ ] **Failing Spec First:** A spec that captures the exact bug was written before the fix.
- [ ] **Minimal Change:** The fix is the smallest possible change that addresses the root cause.
- [ ] **Analogous Code Checked:** Sibling code paths inspected for how they handle the same situation.
- [ ] **Related Occurrences Searched:** If the bug is a pattern, searched for the same pattern elsewhere.
- [ ] **CMDx Patterns Followed:**
  - `catch`/`throw` for signal flow (not exceptions).
  - Signal construction in task private methods only.
  - Context mutations through `store`/`merge`/`delete`.
- [ ] **No Side Effects:** The fix doesn't change behavior for currently-passing scenarios.
- [ ] **Isolated Commit:** Bugfix is not mixed with refactoring.

## 4. Validation

- [ ] **Reproduction Passes:** The previously-failing reproduction script/spec now passes.
- [ ] **Test Suite Passes:** `bundle exec rspec .` passes with zero failures.
- [ ] **Linter Passes:** `bundle exec rubocop .` passes with zero offenses.
- [ ] **No Collateral Regressions:** Related specs (same category/file) inspected and passing.
- [ ] **Edge Cases Tested:** Nil, empty, frozen, and boundary scenarios related to the fix are verified.

## 5. Regression Guard

- [ ] **Spec Covers Exact Input:** The new spec uses the same input shape that triggered the bug.
- [ ] **Edge Cases Covered:** If the bug was at a boundary (nil, empty, frozen), the spec tests that boundary.
- [ ] **Constraint Documented:** If the fix introduces or reveals a non-obvious constraint, a code comment explains it.

## 6. Documentation

- [ ] **One-Line Summary:** Root cause stated in a single sentence for the commit message.
- [ ] **CHANGELOG Updated:** `## Bug Fixes` entry describes what was broken and the root cause.
- [ ] **YARD Updated:** If the fix changed method contracts, params, return types, or added raises, YARD docs are updated.
- [ ] **No Stale Docs:** Existing documentation that contradicts the fix is corrected.

## 7. Anti-Pattern Avoidance

- [ ] **No Broad Rescue:** Fix doesn't introduce `rescue StandardError` that swallows faults.
- [ ] **No Post-Freeze Mutation:** Fix doesn't mutate context after result generation.
- [ ] **No Double Signal:** Fix doesn't introduce paths where multiple halt signals can fire.
- [ ] **No String Keys:** Context lookups use symbol keys.
- [ ] **No External `catch(:cmdx)`:** Fix doesn't intercept `Signal::TAG` outside runtime.
- [ ] **No Nil Guards Masking Upstream Bugs:** Nil checks are justified, not papering over a missing value.
- [ ] **No Debug Code Left:** `binding.break`, `pp`, `puts` debugging removed before commit.
