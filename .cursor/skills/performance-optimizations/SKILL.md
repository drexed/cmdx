---
name: performance-optimizations
description: Profile, benchmark, and optimize CMDx task execution, context handling, and runtime hot paths. Use when the user mentions performance, benchmarking, profiling, memory allocation, optimization, slow execution, or YJIT. Don't use for general refactoring, feature additions, or test-only changes.
---

# Performance Optimization

## Prerequisites

Ensure these tools are available before profiling:

```bash
gem install benchmark-ips memory_profiler ruby-prof
```

## Procedures

**Step 0: Baseline from Siblings**

Inspect **similar code paths** in the repo (e.g. another task class, context builder, or runtime hook) and compare allocation/query patterns. This keeps recommendations aligned with how the rest of CMDx solves the same class of problem and avoids introducing an inconsistent optimization style.

**Step 1: Establish a Baseline**

1. Run `ruby scripts/ips-benchmark.rb` for iterations/second across all scenarios, context construction, and access patterns.
2. Run `ruby scripts/memory-profile.rb [scenario]` for per-file/per-line allocation and retained memory report.
3. Run `ruby scripts/allocation-trace.rb` for per-class allocation counts filtered to CMDx source.
4. Run `ruby scripts/yjit-compare.rb` to measure YJIT speedup delta.
5. Save all outputs to a scratch file for before/after comparison.

All script paths are relative to `.cursor/skills/performance-optimizations/`.

**Step 2: Identify the Bottleneck**

Classify the bottleneck:
  - **CPU-bound** (deep call stacks, slow methods) → focus on algorithmic changes, memoization, or YJIT-friendly patterns.
  - **Allocation-bound** (high GC pressure, many short-lived objects) → focus on object reuse, frozen constants, and avoiding intermediate collections.

Prioritize bottlenecks by **impact × frequency** — a method adding 0.1ms overhead called 1000× per execution outranks a 5ms method called once.

**Step 3: Classify and Apply the Optimization**

Determine which category the fix falls into — prefer low-risk categories first:

| Category | Risk | Examples |
|---|---|---|
| **Allocation reduction** | Low | Frozen strings, `map!` vs `map`, reuse buffers, `EMPTY_HASH`/`EMPTY_ARRAY` |
| **Algorithmic** | Medium | Hash lookup vs linear scan, early returns, `catch`/`throw` vs exceptions |
| **Concurrency** | High | Thread-safe memoization, parallel task execution |
| **Architectural** | High | Structural change to context/runtime data flow |

Then follow these rules in priority order:

1. **Reuse frozen constants** — use `EMPTY_HASH`, `EMPTY_ARRAY`, `EMPTY_STRING` instead of allocating literals in hot paths. These are defined in `lib/cmdx.rb`.
2. **Memoize expensive computations** — use `@foo ||=` for values computed more than once per instance lifetime.
3. **Use `catch`/`throw` for flow control** — this is already the pattern in `Runtime`; never replace it with exceptions for non-error control flow since `throw` is ~10x faster than `raise`.
4. **Estimate impact** before committing — e.g. "reduces allocations ~60%", "eliminates O(n²) lookup". Avoid fake precision; order-of-magnitude or directional estimates are fine.
5. Keep the optimization **isolated** — do not mix performance changes with feature changes in the same commit.

**Step 4: Validate the Change**

1. Re-run `ruby scripts/ips-benchmark.rb` and compare iterations/second against the baseline.
2. Re-run `ruby scripts/memory-profile.rb` and confirm allocated memory/objects decreased (or stayed flat).
3. Re-run `ruby scripts/allocation-trace.rb` and confirm allocation counts decreased (or stayed flat).
4. Run `bundle exec rspec .` to ensure no regressions.
5. Run `bundle exec rubocop .` to ensure style compliance (rubocop-performance cops are active).
6. Verify no regressions in other metrics (e.g. fixing memory shouldn't degrade latency).

**Step 5: Guard Against Regression**

1. Add a spec or benchmark that exercises the optimized path if the bottleneck was severe.
2. Consider **performance budgets** for hot paths — e.g. max allocation count or IPS floor that CI can enforce.
3. If improvement is <5%, reconsider whether the change is worth the added complexity.

**Step 6: Document the Change**

1. Add a `## Performance` entry to `CHANGELOG.md` noting the before/after numbers.
2. If a new frozen constant or memoized value was introduced, add a brief YARD comment explaining the trade-off.

## General Principles

**Measure, don't guess.** Profiling data drives every decision. Intuition about performance is wrong more often than right.

**Optimize the hot path.** Code that runs once during boot doesn't matter. Code in a per-task or per-context-access loop does.

**Reduce allocations before reducing instructions.** In Ruby, GC pressure from object churn often dominates CPU time. Fewer allocations → fewer GC pauses → lower p99 latency.

**Fail fast.** Guard clauses and early returns prevent wasted work. Check the cheapest condition first.

**Prefer lazy over eager (for large datasets).** Use lazy enumerators and streaming when processing unbounded collections.

**Avoid work entirely.** The fastest code is code that doesn't run. Conditional execution and `skip!` guards eliminate unnecessary computation.

**Cache computed results.** If the same computation runs repeatedly with the same inputs, memoize it. Prefer instance-level `@foo ||=` → class-level constant → external cache.

## Anti-Patterns

| Anti-Pattern | Why It Hurts | Fix |
|---|---|---|
| Optimizing without profiling | Wastes time on non-bottlenecks | Profile first, always |
| Micro-optimizing cold paths | No measurable user impact | Focus on hot paths only |
| String concatenation in loops | Creates intermediate string objects | Use `String#<<`, `Array#join`, or `StringIO` |
| Nested loops over collections | O(n²) or worse | Hash lookup, precompute, or restructure |
| Unbounded in-memory collections | RSS spikes, OOM risk, GC stalls | Lazy enumerators, streaming |
| Over-memoizing | Holds references, prevents GC | Memoize only expensive computations |

## Key Patterns

### Frozen Constant Reuse

```ruby
# lib/cmdx.rb already defines these — use them as defaults
EMPTY_ARRAY  = [].freeze
EMPTY_HASH   = {}.freeze
EMPTY_STRING = ""
```

## YJIT Considerations

- Keep methods short and monomorphic — YJIT inlines small methods aggressively.
- Avoid `method_missing` fan-out on the critical path; YJIT cannot optimize dynamic dispatch.
- `freeze` on value objects helps YJIT prove immutability and skip write barriers.
- Run benchmarks with and without YJIT to measure the delta; report both numbers.

## Scripts Reference

| Script | Gem Dependency | Purpose |
|--------|---------------|---------|
| `scripts/ips-benchmark.rb` | `benchmark-ips` | IPS across execution scenarios, context construction, and access patterns with `compare!` |
| `scripts/memory-profile.rb` | `memory_profiler` | Per-file/per-line allocated and retained memory; accepts scenario arg |
| `scripts/allocation-trace.rb` | stdlib (`objspace`) | Per-class allocation counts via ObjectSpace tracing filtered to CMDx |
| `scripts/yjit-compare.rb` | `benchmark-ips` | Side-by-side YJIT on/off runs with speedup ratios (Ruby 3.3+) |

The project also ships `bin/benchmark` (basic IPS) and `bin/profile` (ruby-prof call graph).

## Final Validation

Cross-reference the completed optimization against `references/checklist.md`.

## Error Handling

- If any script fails with `LoadError`, install the missing gem: `gem install benchmark-ips memory_profiler ruby-prof`.
- If `scripts/allocation-trace.rb` reports `0` allocations, the test helpers may be out of sync with the current codebase. Verify `spec/support/helpers/task_builders.rb` defines the referenced builder methods.
- If `scripts/yjit-compare.rb` aborts with "YJIT not available", ensure CRuby 3.1+ built with `--enable-yjit`. Runtime enable requires Ruby 3.3+.
- If benchmark numbers are noisy (>10% variance between runs), increase warmup time or close background processes.
- If profiling shows no clear bottleneck, check whether the system is I/O-bound — external service latency, file reads, or network round trips.
- If an optimization introduces test failures, it changed behavior — revert and re-profile.
- If memory improves but latency worsens (or vice versa), evaluate whether the trade-off is acceptable for the workload.
