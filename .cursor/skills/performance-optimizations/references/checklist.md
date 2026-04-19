# Performance Optimization Checklist

Final audit before merging a CMDx performance optimization. Every item must pass.

## 0. Context Clarification

- [ ] **Hot Path Identified:** The task/runtime path, expected call volume, and performance targets are understood.
- [ ] **Pain Categorized:** The bottleneck class is named — CPU-bound or allocation-bound.
- [ ] **Constraints Stated:** Correctness, deploy risk, and maintainability trade-offs are acknowledged.
- [ ] **Sibling Baseline:** Similar code paths in the repo (other task classes, context builders, runtime hooks) have been inspected to keep the optimization consistent with existing patterns.

## 1. Baseline Measurement

- [ ] **Symptom Identified:** The specific symptom is documented (slow execution, high memory, excess allocations).
- [ ] **Reproducible:** The issue is reproducible under consistent conditions (same task, same context shape).
- [ ] **Scripts Run:** Baseline captured with the profiling scripts:
  - `scripts/ips-benchmark.rb` — iterations/second
  - `scripts/memory-profile.rb` — allocated/retained memory
  - `scripts/allocation-trace.rb` — per-class allocation counts
  - `scripts/yjit-compare.rb` — YJIT on/off delta
- [ ] **Numbers Saved:** Baseline outputs are saved for before/after comparison.

## 2. Profiling

- [ ] **Correct Profiler:** The appropriate tool is used (`benchmark-ips` for throughput, `memory_profiler` for allocations, `stackprof`/`ruby-prof` for call stacks, `ObjectSpace` for allocation tracing).
- [ ] **Bottleneck Identified:** The specific bottleneck is identified by profiling data, not intuition.
- [ ] **Impact × Frequency:** Bottleneck is prioritized by impact multiplied by call frequency.

## 3. Classification

- [ ] **Category Determined:** Optimization is classified as allocation reduction, algorithmic, concurrency, or architectural.
- [ ] **Risk Assessment:** Low-risk categories (allocation reduction) are preferred; high-risk changes (architectural) are justified by profiling data.

## 4. Implementation

- [ ] **CMDx Patterns Followed:** Frozen constants (`EMPTY_HASH`, `EMPTY_ARRAY`, `EMPTY_STRING`), `@foo ||=` memoization, and `catch`/`throw` flow control are used where applicable.
- [ ] **Minimal Change:** The smallest possible change addresses the profiled bottleneck.
- [ ] **Impact Estimated:** Expected improvement is stated directionally (e.g. "reduces allocations ~60%", "eliminates O(n²) lookup") — no fake precision.
- [ ] **Isolated Commit:** Performance change is not mixed with feature changes.
- [ ] **No Premature Abstraction:** The concrete case is optimized first.
- [ ] **YJIT-Friendly:** Methods on the hot path remain short and monomorphic; no `method_missing` fan-out on the critical path.

## 5. Validation

- [ ] **Same Scripts Re-run:** The exact same profiling scripts from Step 1 are re-run.
- [ ] **Compared to Baseline:** Results are compared against saved baseline numbers.
- [ ] **No Regressions:** No regressions in other metrics (memory ↔ latency trade-off evaluated).
- [ ] **Meaningful Improvement:** Improvement is ≥5% or the complexity trade-off is justified.
- [ ] **Tests Pass:** `bundle exec rspec .` passes.
- [ ] **Style Pass:** `bundle exec rubocop .` passes (rubocop-performance cops are active).

## 6. Regression Guard

- [ ] **Spec or Benchmark:** A spec or benchmark exercises the optimized path (for severe bottlenecks).
- [ ] **Performance Budget:** For hot paths, a budget is considered (max allocation count or IPS floor that CI can enforce).
- [ ] **Trade-offs Documented:** Memory vs CPU or complexity vs gain trade-offs are stated when present.
- [ ] **Non-Obvious Comment:** Optimization rationale is documented in a code comment only if the "why" is non-obvious.
- [ ] **CHANGELOG Updated:** `## Performance` entry added with before/after numbers.

## 7. Anti-Pattern Avoidance

- [ ] **No Blind Optimization:** Change is backed by profiling data.
- [ ] **Hot Path Only:** Optimization targets hot paths, not cold/boot paths.
- [ ] **No String Concat in Loops:** Uses `String#<<`, `Array#join`, or `StringIO` instead.
- [ ] **No Over-Memoization:** Memoization is limited to expensive computations; not holding references that prevent GC.
- [ ] **No Unbounded Collections:** Large datasets use lazy enumerators or streaming.
