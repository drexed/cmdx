# Outputs Reference

Docs: [docs/outputs.md](../../docs/outputs.md). Outputs are intentionally minimal — every declared output is implicitly required, and only `:default`, `:if`/`:unless`, and `:description` are configurable. For coercion, transformation, validation, or nested resolution use [inputs.md](inputs.md) (or compute in `work`).

## Declaration

```ruby
output  :source                          # single
output  :user, :token                    # multiple
outputs :generated_at, default: -> { Time.now }

deregister :output, :audit_log, :request_id
```

`output` is an alias of `outputs`. Keys are symbolized.

## Options

| Option | Description |
|--------|-------------|
| `default:` | Static value, Symbol (task method), Proc (`instance_exec`), or `#call(task)`-able. Applied when `context[name]` is nil. Satisfies the implicit required check. |
| `if:` / `unless:` | Skip the entire check (including the implicit required check) when the gate fails. Signature `(task)`. |
| `description:` / `desc:` | Metadata for `outputs_schema`. |

## Verification

Runs **after `work` succeeds**. Skipped entirely when `work` threw `skip!`, `fail!`, or `throw!`. For each declared output in order:

1. Evaluate `if:`/`unless:` — skip if gated.
2. Read `task.context[name]`; apply `:default` when value is `nil`.
3. If the key was never written and no default produced a value, add `cmdx.outputs.missing`.
4. Write the resolved value back to `task.context[name]`.

Failures fold into the same terminal "auto-fail" behavior as input errors: `result.reason` = `task.errors.to_s`, `result.errors[name]` exposes messages. `execute!` raises `CMDx::Fault`.

```ruby
class CreateUser < CMDx::Task
  output :user
  def work
    # forgot to set context.user
  end
end

result = CreateUser.execute
result.failed?        #=> true
result.reason         #=> "user must be set in the context"
result.errors.to_h    #=> { user: ["must be set in the context"] }
```

## Defaults

```ruby
output :version,      default: "v2"                  # literal
output :source,       default: :default_source       # task method
output :generated_at, default: -> { Time.now }       # instance_exec on task
output :tenant,       default: TenantDefaults        # #call(task)-able
```

A default that produces a non-nil value satisfies the implicit required check.

## Inheritance

Subclasses inherit parent outputs via a lazy `dup`. Remove inherited outputs with `deregister :output, :name`.

```ruby
class ApplicationTask < CMDx::Task
  output :audit_log
  output :request_id
end

class LightweightTask < ApplicationTask
  deregister :output, :audit_log, :request_id
end
```

## Schema

```ruby
MyTask.outputs_schema
# => { user: { name: :user, description: "...", options: {...} } }
```
