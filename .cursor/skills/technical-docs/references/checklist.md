# Technical Documentation Checklist

Verify every item before finalizing documentation changes.

## 1. YARD Completeness

- [ ] **Every public class has a class-level doc.** One-sentence purpose + key behavior notes.
- [ ] **Every public method has `@param` and `@return`.** No undocumented parameters.
- [ ] **`@raise` tags present.** Every `raise` in the method body has a corresponding `@raise` tag.
- [ ] **`@yield` / `@yieldparam` present.** Every method accepting a block documents its block signature.
- [ ] **`@example` on non-obvious APIs.** Signal methods, pattern matching, `on` callbacks, `method_missing` accessors.
- [ ] **`@note` on constraint-bearing methods.** Freeze semantics, `throw` flow interruption, thread safety.
- [ ] **`@see` cross-references.** Related methods link to each other (e.g., `execute` ↔ `execute!`).

## 2. Accuracy

- [ ] **Docs match code.** Parameter names, types, and return types reflect current signatures.
- [ ] **No stale tags.** Renamed or removed parameters don't have orphaned `@param` entries.
- [ ] **Signal semantics documented.** Methods using `throw(Signal::TAG)` note that control never returns.
- [ ] **Freeze semantics documented.** `Result.new` freeze cascade is noted on `Result`, `Context#freeze`.
- [ ] **`method_missing` documented.** Dynamic accessor behavior on `Context` is explained.

## 3. Style

- [ ] **Intent first.** First doc line explains why, not what.
- [ ] **No filler.** No restating the method name or parameter name as the description.
- [ ] **Consistent vocabulary.** Uses the CMDx vocabulary table — no synonyms like "command" for "task."
- [ ] **Tag order.** `@param` → `@return` → `@raise` → `@yield` → `@yieldparam` → `@example` → `@note` → `@see`.
- [ ] **Realistic examples.** Examples use CMDx types (task classes, context hashes, result objects), not `foo`/`bar`.

## 4. CHANGELOG

- [ ] **Entry exists for each user-facing change.** New APIs get `### Added`, signature changes get `### Changed`.
- [ ] **Class/method in backticks.** Each entry starts with the affected constant.
- [ ] **No orphaned entries.** Every CHANGELOG bullet corresponds to an actual code change.
- [ ] **Categories ordered.** Added → Changed → Deprecated → Removed → Fixed.

## 5. Tooling

- [ ] **`yard stats --list-undoc` clean.** No new undocumented items introduced.
- [ ] **`rubocop .` clean.** No new offenses from documentation changes.
- [ ] **No debug artifacts.** No `pp`, `puts`, `binding.break` left in documented code.
