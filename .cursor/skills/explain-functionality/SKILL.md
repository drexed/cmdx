---
name: explain-functionality
description: Explains selected code in depth — data flow, dependencies, side effects, and intent. Use when the user asks to explain, trace, walk through, or understand a function, method, class, module, or code block. Emphasizes how and why over what. Don't use for debugging, refactoring, performance tuning, or generating new code.
---

# Explain Functionality

Deep-explanation procedure for any code selection. Emphasizes *why* and *how* over restating *what*.

> **Scope check:** Confirm the exact code region and depth of explanation the user expects before producing output.

## Procedures

**Step 0: Determine Scope**

1. Identify the code the user selected or referenced.
2. If no explicit selection, ask the user to specify the file, class, method, or line range.
3. Read the target code and its surrounding context (imports, class definition, module namespace).
4. Determine **audience depth** — quick overview, moderate walkthrough, or forensic deep-dive. Default to moderate unless the user specifies otherwise.

**Step 1: Map the Structure**

Before explaining line-by-line, build a mental model of the code's shape:

1. **Entry points** — public methods, exported functions, event handlers. What triggers this code?
2. **Internal flow** — call graph within the selection. Which private methods call which? What order do they execute?
3. **Exit points** — return values, emitted signals, enqueued jobs, written records. What leaves this code?
4. **Branching** — conditionals, guard clauses, `catch`/`throw`, error paths. Under what conditions does flow diverge?

Present this as a concise structural overview before diving into details.

**Step 2: Map Data Flow**

Answer: *What goes in, what comes out, and how is data transformed along the way?*

1. Identify all **inputs**: method parameters, instance variables read, context keys accessed, globals, constants, environment variables.
2. Identify all **outputs**: return values, instance variables written, context mutations, yielded values, thrown signals.
3. Trace the transformation pipeline from inputs to outputs. Note type changes (string→symbol, hash→struct, raw→validated).
4. Note branching paths — conditionals, early returns, guard clauses, `catch`/`throw` — and describe which conditions lead to which output.
5. **Implicit data** — memoized values, thread-locals, `Current` attributes. Call out data that flows through hidden channels.
6. For CMDx tasks, pay special attention to:
   - Context reads (`ctx[:key]`, `ctx.key`, `method_missing` delegates).
   - Context writes (`store`, `merge`, `delete`).
   - Signal emission (`success!`, `skip!`, `fail!`, `throw!`) and the data each carries.

Use compact notation when multiple data paths exist:

```
input_param → validate → transform → persist → return result
           ↘ fail! on invalid
```

**Step 3: Identify Dependencies**

Answer: *What does this code rely on to function correctly?*

Catalog everything this code depends on and everything that depends on it:

| Direction | What to Check |
|---|---|
| **Upstream** (code depends on) | Called methods, included modules, inherited behavior, injected services, config values, ENV vars |
| **Downstream** (depends on code) | Callers of this method/class, jobs enqueued, callbacks triggered, signals caught |
| **Lateral** (shared state) | Class variables, memoized singletons, shared caches |
| **Framework conventions** | `work` called by `Runtime`, `catch`/`throw` with `Signal::TAG`, `Context#method_missing` delegation — implicit behavior not visible in the code under analysis |

For each dependency, note:
- **Coupling strength** — hard-coded call vs injected vs duck-typed.
- **Failure mode** — what happens if the dependency is nil, raises, times out, or returns unexpected data.
- **Staleness risk** — can the dependency's value change between read and use (TOCTOU)?

**Step 4: Surface Side Effects**

Answer: *What does this code change beyond its return value?*

Enumerate every state change observable outside the method's return value:

| Category | Examples |
|---|---|
| **State mutations** | Instance variables written, class-level state, context mutated via `store`/`merge`/`delete` |
| **Signal/flow control** | `throw` unwinding the call stack, exceptions raised, `Fault` propagation |
| **I/O** | File writes, network calls, logging |
| **Job dispatch** | Enqueued background work |
| **Cache mutation** | Memoization on shared objects (`@foo ||=`); note invalidation strategy or lack of one |
| **Callbacks** | `after_save`, lifecycle hooks — invisible control flow |

For each side effect, state:
- **When** it fires (always, conditionally, on success only, on failure only).
- **Reversibility** — can it be undone if a later step fails? (transactional writes yes, sent emails no).
- **Idempotent?** — safe to repeat, or duplicating causes problems.

**Step 5: Explain Intent (the Why)**

Code shows *what* happens; the explanation must convey *why*.

1. **Design intent** — why does this code exist? What problem or requirement does it satisfy?
2. **Approach rationale** — why this implementation over alternatives? Note trade-offs (performance vs readability, safety vs flexibility).
3. **Non-obvious choices** — guard clauses that prevent subtle bugs, ordering that matters, seemingly redundant checks.
4. **Historical context** — if git blame or specs reveal why a decision was made, include it. "This eager load was added to fix an N+1" beats "this eager loads the association."
5. **Domain semantics** — translate code constructs into business language when applicable.
6. **Technical debt signals** — `TODO`, `FIXME`, `HACK`, `XXX` markers and known limitations. Surface them so the reader knows what's deferred vs complete.

**Step 6: Assess Edge Cases and Assumptions**

1. List implicit assumptions the code makes (e.g., input is never nil, context key always present, array is non-empty).
2. Identify edge cases that could violate those assumptions.
3. Note any defensive coding already present (guard clauses, type checks, default values).
4. Flag missing guards that could cause unexpected behavior.
5. Note race conditions, ordering assumptions, or TOCTOU risks if applicable.

**Step 7: Compose the Explanation**

Structure the output using the template in `assets/explanation-template.md`. Adapt section depth to the complexity of the code:

| Code Complexity | Depth | Typical Output |
|---|---|---|
| Single method, < 10 lines | Light | 3–5 sentences covering intent, data flow, and any gotcha |
| Method with branching or callbacks | Moderate | Structured walkthrough with flow diagram and side effects |
| Class or module | Full | All steps; dependency map; cross-reference callers/callees |
| Multi-file flow (task → runtime → signal) | Forensic | End-to-end trace across files; sequence of side effects |

## Output Guidelines

- Lead with a **one-sentence summary** in domain terms before any detail.
- Use concrete values in examples, not abstract placeholders.
- When describing data flow, show a before/after of the data shape when the transformation is non-trivial.
- Reference line numbers and file paths so the reader can navigate back to source.
- Use code references (`` `method_name` ``, `` `ClassName` ``) to anchor prose to code.
- Prefer inline code flow diagrams over paragraph-heavy descriptions for complex paths.
- **Mermaid diagrams** — use when they clarify structure better than prose:
  - Sequence diagrams for multi-object interactions (task → runtime → signal → result).
  - Flowcharts for branching logic and guard clauses.
  - State diagrams for lifecycle transitions.
  - Keep compact (≤15 nodes); omit if they'd be noise.
- Omit sections that add no value — a pure function needs no side-effects section.
- Close complex explanations with a **quick reference table**:

  | Item | Value |
  |---|---|
  | Entry point | method/action that triggers this code |
  | Key classes | classes and modules involved |
  | Side effects | non-obvious state changes |

- Keep the tone direct and technical — no filler, no hedging.

## CMDx-Specific Vocabulary

Use these terms consistently when explaining CMDx code:

| Term | Meaning |
|---|---|
| **Task** | A unit of work defined by a class with a `work` method |
| **Context** | The shared data object (`ctx`) passed through task execution |
| **Signal** | The halt mechanism (`success!`, `skip!`, `fail!`) that short-circuits via `catch`/`throw` |
| **Result** | The frozen outcome object containing state, status, reason, metadata, and context |
| **Fault** | An exception subclass used for `execute!` error propagation |
| **Runtime** | The execution wrapper that manages `catch`/`throw` flow and exception rescue |

## Anti-Patterns

| Anti-Pattern | Why It Hurts | Fix |
|---|---|---|
| Restating code in English | "This calls `find`" adds zero value | Explain **why** it calls `find` and what happens if it returns nil |
| Ignoring implicit behavior | Callbacks, concerns, `method_missing` delegation are invisible but critical | Always check for `included` blocks, lifecycle hooks, and framework conventions |
| Explaining in isolation | Code exists in a call chain; severing context loses meaning | Trace at least one level up (caller) and one level down (callee) |
| Assuming reader knows the domain | Technical explanation without business context is half an explanation | Translate code constructs to domain language |
| Over-explaining simple code | Wastes reader attention on trivial lines | Scale depth to complexity |
| Skipping error/failure paths | Happy path is often obvious; error handling reveals design intent | Enumerate failure modes and their consequences |

## Error Handling

- If the selected code is too large (>200 lines), ask the user to narrow scope or break the explanation into sections by class/method.
- If the selected code references files that don't exist, note the broken dependency and explain what the code *expects* to be there.
- If the code is incomplete (partial selection), state the assumptions made about the missing context and flag them clearly.
- If YARD docs contradict actual behavior, flag the discrepancy and trust the code.
- If intent is truly ambiguous after checking history, specs, and naming, present the two most likely interpretations and let the user decide.

## Final Validation

Cross-reference the completed explanation against `references/checklist.md`.
