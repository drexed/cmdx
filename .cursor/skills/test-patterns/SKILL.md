---
name: test-patterns
description: Write, structure, and maintain RSpec specs for CMDx tasks, workflows, context, and configuration. Use when the user asks to add, update, fix, or refactor tests, write specs for new features, scaffold test files, or follow project testing conventions. Don't use for debugging production bugs, performance benchmarking, or non-test code changes.
---

# Test Patterns

> **Scope check:** Confirm what is being tested (task, workflow, context, configuration, or module) and whether the spec is unit or integration before writing code.

> **Bug-first rule:** If you discover a bug in the source code while writing or debugging a spec, ask the user whether they want to fix the bug before proceeding. Never silently work around a bug in the test (e.g. adjusting expectations to match broken behavior, skipping a scenario, or adding setup that compensates for the defect).

## Prerequisites

Ensure the test suite and linter pass before making changes:

```bash
bundle exec rspec .
bundle exec rubocop .
```

## Procedures

**Step 1: Classify the Spec**

Determine the spec type based on what is under test:

| Type | Directory | `RSpec.describe` target | Metadata |
|---|---|---|---|
| **Unit** | `spec/cmdx/` | Constant (`CMDx::Context`) | none |
| **Module** | `spec/` | Constant (`CMDx`) | none |
| **Integration** | `spec/integration/<area>/` | String (`"Task execution"`) | `type: :feature` |

Place the file in the matching directory. Mirror the `lib/` path for unit specs (e.g., `lib/cmdx/context.rb` → `spec/cmdx/context_spec.rb`). Group integration specs by area: `tasks/`, `workflows/`.

After classifying, scan 1–2 existing specs in the same directory. Mirror their `describe`/`context` structure, matchers, and setup style so the new spec reads like a sibling.

**Step 2: Scaffold the Spec File**

Read `assets/spec-template.md` and use the appropriate template (unit or integration) as the starting point.

Every spec file must:
1. Start with `# frozen_string_literal: true`
2. Require `"spec_helper"` (never `rails_helper`)
3. Use `RSpec.describe` at the top level — no `module` wrappers
4. Use `expect` syntax exclusively — never `should`

**Step 3: Structure the Spec**

Follow these nesting conventions:

1. **Top-level `describe`** — the class/module or feature string.
2. **Method-level `describe`** — use `".method_name"` for class methods, `"#method_name"` for instance methods. Skip for integration specs.
3. **`context` blocks** — group by conditions using `"when ..."` or `"with ..."` prefixes. Nest deeply when exercising multiple dimensions (execution mode × task outcome).
4. **`it` blocks** — one behavior per example, but multiple assertions are encouraged via global `aggregate_failures`.

Naming rules:
- `describe` takes a string or constant — never both.
- `context` always starts with `"when"`, `"with"`, or `"without"`.
- `it` descriptions state the expected outcome, not the setup. A failing spec name should explain *what broke* without reading the source.
- Use `described_class` to reference the class under test inside examples — never hardcode the constant.

**Step 4: Set Up Test Data**

Use the project's builder helpers — never FactoryBot, Fabrication, or bare `double`.

| Builder | Returns | Use for |
|---|---|---|
| `create_task_class(base:, name:, &block)` | Anonymous task class | Custom `work` logic |
| `create_successful_task` | Task that appends `:success` | Happy-path execution |
| `create_skipping_task(reason:, **metadata)` | Task that calls `skip!` | Skip flow |
| `create_failing_task(reason:, **metadata)` | Task that calls `fail!` | Failure flow |
| `create_erroring_task(reason:)` | Task that raises `CMDx::TestError` | Exception handling |
| `create_nested_task(strategy:, status:)` | Outer→Middle→Inner chain | Nested execution with `:swallow`, `:throw`, or `:raise` |
| `create_workflow_class(base:, name:, &block)` | Workflow class with `CMDx::Workflow` | Workflow composition |
| `create_successful_workflow` | Workflow with mixed tasks | Workflow happy path |
| `create_skipping_workflow` | Workflow with a skipping inner task | Workflow skip flow |
| `create_failing_workflow` | Workflow with a failing inner task | Workflow failure flow |
| `create_erroring_workflow` | Workflow with an erroring inner task | Workflow error flow |

Guidelines:
- Prefer `let(:task)` / `let(:workflow)` for the object under test.
- Use `subject(:result)` for the execution result when the entire example group tests one call.
- Pass blocks to builders for inline DSL (`settings`, `task`, `tasks`, custom methods).
- Prefer real objects over mocks. Use stubs only to return predefined values when isolating a unit; avoid over-mocking. Use `instance_double` only when necessary; never `double`.

**Step 5: Write Assertions**

Follow these matcher conventions:

| Scenario | Pattern |
|---|---|
| Result state/status | `have_attributes(state: CMDx::Signal::COMPLETE, status: CMDx::Signal::SUCCESS, ...)` |
| Context values | `expect(result.context).to have_attributes(executed: %i[...])` or `be_empty` |
| Exception raising | `expect { result }.to raise_error(CMDx::FailFault, "message")` |
| Block yielding | `expect { \|b\| described_class.configure(&b) }.to yield_with_args(CMDx::Configuration)` |
| Collection contents | `contain_exactly(...)` for unordered, `eq([...])` for ordered |
| Identity | `be(object)` for same object, `eq(value)` for equality |
| Type | `be_a(CMDx::Configuration)` |
| Boolean predicate | `be(true)` / `be(false)` — not `be_truthy`/`be_falsy` |
| Nested hash matching | `hash_including(key: value)` |
| String prefix | `start_with("OuterTask")` |

Coverage:
- Cover both typical cases and edge cases — invalid inputs, error conditions, nil, empty, frozen, and boundary values.
- Integration expectations should be realistic — test the API how it would actually be used, not contrived scenarios.
- When touching an existing spec file, update pre-existing examples to match current conventions.

What NOT to test:
- Declarative configuration (e.g., `settings` DSL output that just stores values).
- Obvious reflective expectations (e.g., "it returns what was passed in" for trivial getters).
- Constants, enum lists, or attribute declarations — test *behavior* callers rely on, not structure.

**Step 6: Handle Setup and Teardown**

- Use `let` / `let!` for test data. Prefer lazy `let` unless eagerness is required. Avoid instance variables.
- Use `before` / `after` for state mutation (e.g., `CMDx.reset_configuration!`).
- Use `subject(:name)` when the return value of the call is the focus of the group.
- Never rely on example ordering — specs run in `--order random`.
- No cross-example shared mutable state — avoid class variables, global mutation, or leaked state that causes order-dependent failures. Each example must be independent.

**Step 7: Verify**

1. Run the full suite: `bundle exec rspec .`
2. Run the linter: `bundle exec rubocop .`
3. Confirm new specs are picked up (check file naming ends in `_spec.rb`).
4. Confirm no commented-out code or debug output (`pp`, `puts`, `binding.break`).

Cross-reference the completed spec against `references/checklist.md`.

## Spec Placement Decision Tree

1. **Does it test a single class/module's public API in isolation?**
   - Yes → `spec/cmdx/<class_name>_spec.rb` (unit)
   - No → Go to 2.
2. **Does it test execution flow across tasks or workflows?**
   - Yes → `spec/integration/<area>/` with `type: :feature`
   - No → Go to 3.
3. **Does it test the top-level `CMDx` module?**
   - Yes → `spec/cmdx_spec.rb`
   - No → Ask the user for clarification.

## Existing Patterns Quick Reference

| Pattern | Where Used | Mechanism |
|---|---|---|
| Result attribute assertion | Task execution specs | `have_attributes(state:, status:, reason:, metadata:, cause:)` |
| Context emptiness check | Skip/fail specs | `expect(result.context).to be_empty` |
| Nested propagation strategies | Task execution specs | `create_nested_task(strategy: :throw, status: :failure)` |
| Workflow conditional | Workflow conditionals spec | `task task1, if: :method?` / `if: proc { ... }` / `unless:` |
| Workflow breakpoints | Workflow breakpoints spec | `settings(workflow_breakpoints: %w[skipped failed])` |
| Group-level breakpoints | Workflow breakpoints spec | `tasks t1, t2, breakpoints: []` |
| Bang vs non-bang execution | Workflow/task execution specs | `execute` returns result, `execute!` raises `CMDx::FailFault` |
| Configuration reset | `cmdx_spec.rb` | `after { described_class.reset_configuration! }` |
| Runtime context mutation | Conditionals spec | Setup task writes to context, later task reads via `if: proc` |

## Error Handling

- If `bundle exec rspec .` shows failures unrelated to the new spec, investigate before proceeding — the suite should be green before and after.
- If RuboCop flags `RSpec/` cop violations, fix them inline. Common ones: `RSpec/NestedGroups` (max depth), `RSpec/MultipleExpectations` (not an issue — `aggregate_failures` is global), `RSpec/ExampleLength`.
- If a builder doesn't exist for the needed test scenario, extend the builder module in `spec/support/helpers/` following the existing naming pattern rather than creating a one-off helper.
