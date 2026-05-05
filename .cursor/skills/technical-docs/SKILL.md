---
name: technical-docs
description: Write, update, and maintain YARD documentation and CHANGELOG entries for CMDx classes, modules, and methods. Use when the user asks to document, add YARD docs, update docs, write docstrings, add @param/@return tags, update CHANGELOG, or fix documentation inconsistencies. Don't use for README generation, non-agentic library docs, or code-only changes.
---

# Technical Documentation

> **Scope check:** Confirm which classes, modules, or methods need documentation and whether CHANGELOG updates are required before writing.

## Prerequisites

Ensure YARD is available and the codebase is lintable:

```bash
bundle exec yard stats --list-undoc
bundle exec rubocop .
```

## Procedures

**Step 1: Identify Documentation Targets**

1. Determine what needs documentation: new code, changed signatures, missing YARD tags, or CHANGELOG entries.
2. Run `bundle exec yard stats --list-undoc` to find undocumented methods and classes.
3. Read the source file(s) to understand the public API, parameters, return types, and side effects.
4. Check git diff for recently changed method signatures — these need doc updates.

**Step 2: Read Existing Documentation**

Before writing, scan adjacent documented code in the same file or module:

1. Match the tone, depth, and tag order of sibling methods.
2. Note any `@see`, `@note`, or `@example` patterns already in use.
3. Ensure new docs read as siblings — not outliers.

**Step 3: Write YARD Documentation**

Use the templates in `assets/yard-templates.md` as starting points. Adapt to the code's complexity.

Core rules:

1. **Document every public method and class.** Private methods only when behavior is non-obvious (signal methods, `method_missing` delegates).
2. **No `CMDx` module-level docs.** Do not add YARD documentation to the top-level `module CMDx` declaration.
3. **Module/class-level docs: description only.** No `@example` or `@since` on module or class-level docstrings.
4. **Lead with intent.** The first line answers "what does this do and why?" — not "this method does X."
5. **Use `@param`, `@option`, `@return`, `@raise`, `@yield`, `@yieldparam`, `@example`** — in that order.
6. **Expand hash params with `@option`.** When a `@param` is a `Hash`, enumerate its keys with `@option` tags.
7. **No `@since` anywhere.** Neither module-level nor method-level docs use `@since`.
8. **Type annotations use YARD syntax:** `String`, `Symbol`, `Hash{Symbol => Object}`, `Array<String>`, `nil`, `void`, `Boolean`.
9. **`@return [void]`** for methods whose return value is not part of the API contract (side-effect-only methods, signal methods).
10. **Frozen return values** — note when a return value is frozen (e.g., `Result`, `Context` after signal).
11. **`@note`** for constraints the caller must know: thread safety, freeze semantics, `catch`/`throw` flow interruption.
12. **`@see`** for cross-references to related classes or methods.
13. **`@example`** on methods for non-obvious usage. Keep examples minimal — 3–5 lines max.
14. **No filler.** Don't restate the method name. `# Stores a value` on `#store` adds nothing — explain the symbolization or overwrite semantics instead.

**Step 4: Document CMDx-Specific Patterns**

These patterns require special documentation attention:

| Pattern | Documentation Focus |
|---|---|
| Signal methods (`success!`, `skip!`, `fail!`, `throw!`) | Document `throw` semantics — method never returns. Note `@raise` for double-signal. |
| `Context#method_missing` | Document dynamic accessor behavior, `=` suffix for store, `?` suffix for presence. |
| `Context.build` passthrough | Document when a new context is created vs when the existing one is reused. |
| `Result` freeze cascade | Document that `Result.new` freezes both the result and its context. |
| `Runtime.execute` | Document `catch`/`throw` flow, exception rescue chain, and `raise_signal` behavior. |
| `on` callbacks | Document chaining pattern and predicate dispatch. |
| Pattern matching (`deconstruct`, `deconstruct_keys`) | Document the array/hash shapes returned for `case`/`in` usage. |

**Step 5: Update CHANGELOG**

When documenting alongside code changes, update `CHANGELOG.md`:

1. Add entries under the appropriate `## [Unreleased]` section.
2. Use these categories in order: `### Added`, `### Changed`, `### Deprecated`, `### Removed`, `### Fixed`.
3. Each entry is a single bullet starting with the affected class/method in backticks.
4. Format: `` - `ClassName#method` — description of what changed ``
5. Group related changes under the same category.

**Step 6: Verify**

1. Run `bundle exec yard stats --list-undoc` — undocumented count should decrease or stay at zero.
2. Run `bundle exec rubocop .` — no new offenses.
3. Cross-reference the completed documentation against `references/checklist.md`.

## YARD Tag Reference

| Tag | Usage | When |
|---|---|---|
| `@param name [Type] description` | Method parameters | Always for public methods |
| `@option name [Type] :key description` | Hash param keys | When `@param` is a Hash |
| `@return [Type] description` | Return value | Always |
| `@raise [ExceptionClass] description` | Exceptions raised | When method can raise |
| `@yield [Type] description` | Block parameter | When method accepts a block |
| `@yieldparam name [Type] description` | Block parameters | When block receives arguments |
| `@example Title` | Usage example | Non-obvious APIs |
| `@note` | Constraints, caveats | Freeze, thread safety, flow interruption |
| `@see ClassName#method` | Cross-reference | Related methods or classes |
| `@api private` | Visibility marker | Internal methods exposed by Ruby's visibility |
| `@deprecated Use X instead` | Deprecation notice | Deprecated methods |
| `@overload` | Multiple signatures | Methods with polymorphic arguments |
| `@abstract` | Abstract methods | Template methods like `#work`, `#rollback` |
| `@todo` | Incomplete implementation | Placeholder methods |

## CMDx Vocabulary

Use these terms consistently in documentation prose:

| Term | Meaning | Don't Say |
|---|---|---|
| **Task** | Unit of work with a `work` method | command, service, action |
| **Context** | Shared data object (`ctx`) passed through execution | params, attributes, state |
| **Signal** | Halt mechanism via `catch`/`throw` | event, message, notification |
| **Result** | Frozen outcome containing state, status, reason, metadata, context | response, output |
| **Fault** | Exception subclass for `execute!` error propagation | error (too generic) |
| **Runtime** | Execution wrapper managing `catch`/`throw` and rescue | executor, runner |
| **state** | Execution lifecycle: `executing`, `complete`, `interrupted` | phase, stage |
| **status** | Outcome: `success`, `skipped`, `failed` | result (ambiguous with Result) |

## Anti-Patterns

| Anti-Pattern | Why It Hurts | Fix |
|---|---|---|
| Restating the method name | `# Stores a key` on `#store` wastes tokens | Explain semantics: symbolization, overwrite behavior |
| Missing `@return` on public methods | YARD reports undocumented; callers can't infer types | Always add `@return` — use `void` for side-effect-only |
| Documenting private helpers extensively | Inflates docs, creates maintenance burden | Use `@api private` one-liner or skip |
| Stale parameter names | Renamed params with old `@param` tags mislead | Update `@param` tags when signatures change |
| Examples with fake data | `foo`, `bar`, `baz` examples don't help | Use realistic CMDx examples: task classes, context hashes |
| Documenting what, not why | "Returns the state" — obvious from the method name | "Returns the execution lifecycle state, frozen after result creation" |
| Missing signal semantics | Callers don't know `success!` never returns | Add `@note Throws `:cmdx` — control never returns to caller` |
| CHANGELOG without class reference | "Fixed a bug" is useless | `` `Context#merge` — fixed symbol key conversion on nested hashes `` |

## Error Handling

- If `yard stats` is not available, fall back to manual inspection of public methods without YARD comments.
- If a method's return type is genuinely polymorphic, use `@overload` to document each signature separately.
- If documentation contradicts code behavior, update the documentation to match the code — never the reverse.
- If a `@todo` tag exists on a method, preserve it and add documentation for the currently implemented behavior.
