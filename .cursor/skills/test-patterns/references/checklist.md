# Test Patterns Checklist

Final audit before committing a new or modified spec. Every item must pass.

## 1. File Structure

- [ ] **Frozen String Literal:** File starts with `# frozen_string_literal: true`.
- [ ] **Require:** File requires `"spec_helper"` — not `rails_helper` or anything else.
- [ ] **Placement:** File is in the correct directory (`spec/cmdx/` for unit, `spec/integration/<area>/` for integration).
- [ ] **Naming:** File ends in `_spec.rb`. Unit specs mirror the `lib/` path.
- [ ] **No Module Wrappers:** Top level is `RSpec.describe`, not wrapped in a module.

## 2. Describe and Context

- [ ] **Top-Level Describe:** Uses a constant for unit specs, a string with `type: :feature` for integration specs.
- [ ] **Method Describes:** Uses `".method"` for class methods, `"#method"` for instance methods.
- [ ] **Context Prefixes:** Every `context` description starts with `"when"`, `"with"`, or `"without"`.
- [ ] **No Redundant Nesting:** Context blocks add meaningful behavioral dimensions, not just indentation.

## 3. Test Data

- [ ] **Builders Used:** Test tasks and workflows are created via `CMDx::Testing::TaskBuilders` / `WorkflowBuilders`.
- [ ] **No Raw Doubles:** No `double(...)` calls. `instance_double` only when strictly necessary.
- [ ] **No FactoryBot:** No external factory gems.
- [ ] **Lazy Let:** `let` is preferred over `let!` unless eager evaluation is required.
- [ ] **Named Subject:** `subject(:result)` or `subject(:context)` used when the group tests a single call.

## 4. Assertions

- [ ] **Expect Syntax:** Only `expect(...).to` — no `should`.
- [ ] **Aggregate Failures:** Multiple `expect` calls per example are fine (global `aggregate_failures`).
- [ ] **Correct Matchers:** `be(obj)` for identity, `eq(val)` for equality, `have_attributes` for result state, `raise_error` for exceptions.
- [ ] **No Obvious Tests:** No specs that merely assert a value equals itself or test trivial getters.
- [ ] **No Declarative Config Tests:** Settings DSL output is not tested as a standalone assertion.

## 5. Setup and Teardown

- [ ] **No Order Dependency:** Specs pass in `--order random` without relying on execution sequence.
- [ ] **State Cleaned:** Any global state mutation (e.g., `CMDx.configure`) is reset in `after` blocks.
- [ ] **No Side Effects:** Specs don't write to disk, make network calls, or mutate shared constants.

## 6. Code Quality

- [ ] **RSpec Passes:** `bundle exec rspec .` exits with zero failures.
- [ ] **RuboCop Passes:** `bundle exec rubocop .` exits with zero offenses.
- [ ] **No Debug Code:** No `pp`, `puts`, `binding.break`, or commented-out code left in specs.
- [ ] **No Commented Specs:** No `xit`, `xdescribe`, `xcontext`, or `pending` without justification.
