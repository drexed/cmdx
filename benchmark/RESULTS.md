# CMDx Benchmark Results: v1 (1.21.0) vs v2 (2.0.0)

## System Information

| Property | Value |
|---|---|
| CPU | Apple M1 Pro |
| Memory | 32 GB |
| Architecture | arm64 |
| OS | macOS 26.4.1 (Build 25E253) |
| Ruby | 4.0.0 (2025-12-25 revision 553f1675f3) +PRISM [arm64-darwin25] |
| YJIT | disabled |
| Date | 2026-04-18 |

## Versions Under Test

| Label | CMDx Version | Git SHA |
|---|---|---|
| v1 (baseline) | 1.21.0 | e20d7aa4 |
| v2 | 2.0.0 | 3116ee6c |

---

## IPS (iterations/second) -- higher is better

### Task Execution

| Benchmark | v1 (i/s) | v2 (i/s) | Delta |
|---|---:|---:|---:|
| success | 79,709.3 | 90,925.0 | **+14.1%** |
| skip! | 36,789.3 | 96,569.6 | **+162.5%** |
| fail! | 36,720.3 | 82,757.1 | **+125.4%** |
| error (rescue) | 69,128.0 | 86,563.1 | **+25.2%** |
| nested (3-deep) | 32,003.9 | 38,190.0 | **+19.3%** |

### Workflow Execution

| Benchmark | v1 (i/s) | v2 (i/s) | Delta |
|---|---:|---:|---:|
| workflow success (3 tasks) | 15,750.1 | 18,830.2 | **+19.6%** |
| workflow failure (halting) | 6,069.9 | 17,326.1 | **+185.4%** |

### Context Construction

| Benchmark | v1 (i/s) | v2 (i/s) | Delta |
|---|---:|---:|---:|
| Context.new (3 sym keys) | 2,611,008.9 | 2,718,211.2 | **+4.1%** |
| Context.new (3 str keys) | 2,594,568.1 | 2,767,112.2 | **+6.7%** |
| Context.new (50 sym keys) | 240,652.3 | 252,674.2 | **+5.0%** |
| Context.build (passthrough) | 2,328,444.4 | 2,447,361.1 | **+5.1%** |

### Context Access

| Benchmark | v1 (i/s) | v2 (i/s) | Delta |
|---|---:|---:|---:|
| ctx[:a] (bracket) | 16,077,743.3 | 16,864,817.4 | **+4.9%** |
| ctx.fetch(:a) | 9,191,399.2 | 9,645,896.0 | **+4.9%** |
| ctx.a (method_missing) | 6,163,262.7 | 4,887,819.0 | -20.7% |
| ctx.a = 1 (mm setter) | 3,530,007.1 | 3,707,047.0 | **+5.0%** |
| ctx.key?(:a) | 10,747,062.8 | 15,296,420.5 | **+42.3%** |

---

## Memory Profiling (per single execution) -- lower is better

### Allocated Memory (bytes)

| Scenario | v1 | v2 | Delta |
|---|---:|---:|---:|
| success | 3,520 | 2,800 | **-20.5%** |
| skip! | 12,596 | 2,480 | **-80.3%** |
| fail! | 12,596 | 4,600 | **-63.5%** |
| error (rescue) | 3,520 | 2,480 | **-29.5%** |
| nested (3-deep) | 8,880 | 7,120 | **-19.8%** |
| workflow success | 17,808 | 14,200 | **-20.3%** |
| workflow failure | 99,756 | 30,720 | **-69.2%** |

### Allocated Objects (count)

| Scenario | v1 | v2 | Delta |
|---|---:|---:|---:|
| success | 31 | 30 | **-3.2%** |
| skip! | 86 | 25 | **-70.9%** |
| fail! | 86 | 49 | **-43.0%** |
| error (rescue) | 30 | 27 | **-10.0%** |
| nested (3-deep) | 73 | 72 | **-1.4%** |
| workflow success | 144 | 139 | **-3.5%** |
| workflow failure | 667 | 331 | **-50.4%** |

### Retained Memory

Zero retention across all scenarios for both versions.

---

## Object Allocations (top classes per scenario)

### success

| Class | v1 | v2 | Delta |
|---|---:|---:|---:|
| Hash | 17 | 12 | -29.4% |
| Array | 6 | 7 | +16.7% |
| String | 1 | 3 | +200.0% |
| CMDx::Executor | 1 | 0 | -100.0% |
| CMDx::Runtime | 0 | 1 | new |
| Logger | 0 | 1 | new |
| Thread::Mutex | 1 | 1 | -- |
| CMDx::Errors | 1 | 1 | -- |
| CMDx::Context | 1 | 1 | -- |
| CMDx::Chain | 1 | 1 | -- |
| CMDx::Result | 1 | 1 | -- |

### nested (3-deep)

| Class | v1 | v2 | Delta |
|---|---:|---:|---:|
| Hash | 45 | 32 | -28.9% |
| Array | 12 | 15 | +25.0% |
| String | 1 | 7 | +600.0% |
| CMDx::Executor | 3 | 0 | -100.0% |
| CMDx::Runtime | 0 | 3 | new |
| Logger | 0 | 3 | new |
| CMDx::Errors | 3 | 3 | -- |
| CMDx::Result | 3 | 3 | -- |
| Thread::Mutex | 1 | 1 | -- |
| CMDx::Chain | 1 | 1 | -- |
| CMDx::Context | 1 | 1 | -- |

### workflow success

| Class | v1 | v2 | Delta |
|---|---:|---:|---:|
| Hash | 90 | 63 | -30.0% |
| Array | 25 | 29 | +16.0% |
| String | 1 | 13 | +1200.0% |
| CMDx::Executor | 6 | 0 | -100.0% |
| CMDx::Runtime | 0 | 6 | new |
| Logger | 0 | 6 | new |
| CMDx::Errors | 6 | 6 | -- |
| CMDx::Result | 6 | 6 | -- |
| CMDx::Pipeline | 1 | 1 | -- |
| Thread::Mutex | 1 | 1 | -- |
| CMDx::Chain | 1 | 1 | -- |

---

## RSS (Resident Set Size) -- 1,000 iterations each

| Metric | v1 (MB) | v2 (MB) | Delta |
|---|---:|---:|---:|
| Before | 60.75 | 60.72 | -0.0% |
| After tasks | 60.78 | 60.75 | -0.0% |
| After workflows | 60.78 | 60.75 | -0.0% |
| Task growth | 0.03 | 0.03 | -- |
| Workflow growth | 0.00 | 0.00 | -- |

---

## GC Stats -- 1,000 iterations each

### After Task Execution

| Metric | v1 | v2 | Delta |
|---|---:|---:|---:|
| total_allocated_objects | 56,002 | 50,002 | **-10.7%** |
| heap_live_slots | 17,263 | 23,903 | +38.5% |
| major_gc_count | 0 | 0 | -- |
| minor_gc_count | 1 | 1 | -- |

### After Workflow Execution

| Metric | v1 | v2 | Delta |
|---|---:|---:|---:|
| total_allocated_objects | 248,002 | 209,002 | **-15.7%** |
| heap_live_slots | -703 | 228 | -- |
| major_gc_count | 0 | 0 | -- |
| minor_gc_count | 7 | 5 | **-28.6%** |

---

## Summary

| Area | Verdict |
|---|---|
| Task IPS (success) | v2 is **1.14x faster** (+14.1%) |
| Task IPS (skip!) | v2 is **2.62x faster** (+162.5%) |
| Task IPS (fail!) | v2 is **2.25x faster** (+125.4%) |
| Task IPS (error rescue) | v2 is **1.25x faster** (+25.2%) |
| Workflow IPS (success) | v2 is **1.20x faster** (+19.6%) |
| Workflow IPS (failure) | v2 is **2.85x faster** (+185.4%) |
| Memory (success) | v2 uses **20.5% less** memory |
| Memory (workflow failure) | v2 uses **69.2% less** memory |
| GC allocations (tasks) | v2 allocates **10.7% fewer** objects |
| GC allocations (workflows) | v2 allocates **15.7% fewer** objects |
| RSS footprint | parity (~0%) |
| Context method_missing | v2 is **20.7% slower** (known trade-off for `?` predicate support) |
| Context key? | v2 is **42.3% faster** |
