# Outputs Reference

Docs: [docs/outputs.md](../../docs/outputs.md). Outputs share coercions, validators, transforms, and defaults with inputs — see [inputs.md](inputs.md).

## Declaration

```ruby
output  :source                         # single, optional
output  :user, :token, required: true   # multiple, required
outputs :generated_at, default: -> { Time.now }

deregister :output, :audit_log, :request_id
```

`output` is an alias of `outputs`. Keys are symbolized.

## Options

| Option | Description |
|--------|-------------|
| `required:` | Adds `cmdx.outputs.missing` error if `context[name]` is absent/nil after `work` and no default resolves. |
| `default:` | Static value, Symbol (task method), Proc (`instance_exec`), or `#call(task)`-able. Applied when `context[name]` is nil. |
| `coerce:` | Same as inputs (single Symbol, array, Hash, or callable). |
| `transform:` | Symbol, Proc (`instance_exec(value)`), or `#call(value, task)`. Applied post-coerce, pre-validate. |
| `validate:` | Inline validator (Symbol/Proc/`#call`-able or Array chain). |
| `if:` / `unless:` | Skip the entire check (including `required:`) when the gate fails. Signature `(task)`. |
| Validator shorthands | `presence:`, `absence:`, `format:`, `length:`, `numeric:`, `inclusion:`, `exclusion:`, plus custom validators. |
| `description:` / `desc:` | Metadata for `outputs_schema`. |

## Verification

Runs **after `work` succeeds**. Skipped entirely when `work` threw `skip!`, `fail!`, or `throw!`. For each declared output in order:

1. Evaluate `if:`/`unless:` — skip if gated.
2. Read `task.context[name]`; apply `:default` when value is `nil`.
3. If `required?` and nothing resolved, add `cmdx.outputs.missing`.
4. Coerce; a `Coercions::Failure` short-circuits transform/validate.
5. Apply `:transform`.
6. Run validators.
7. Write the final value back to `task.context[name]`.

Failures fold into the same terminal "auto-fail" behavior as input errors: `result.reason` = `task.errors.to_s`, `result.errors[name]` exposes messages. `execute!` raises `CMDx::Fault`.

```ruby
class CreateUser < CMDx::Task
  output :user, required: true
  def work
    # forgot to set context.user
  end
end

result = CreateUser.execute
result.failed?        #=> true
result.reason         #=> "user must be set in the context"
result.errors.to_h    #=> { user: ["must be set in the context"] }
```

## Defaults, transforms, validators

Same mechanisms as inputs — refer to [inputs.md](inputs.md).

```ruby
output :version,        default: "v2"
output :source,         default: :default_source          # method
output :generated_at,   default: -> { Time.now }          # instance_exec
output :retention_days, default: "7", coerce: :integer    # flows through coerce

output :email, coerce: :string, transform: :downcase
output :tags,  coerce: :array,  transform: proc { |v| v.uniq.sort }
output :total, coerce: :big_decimal, numeric: { min: 0.01 }
```

## Inheritance

Subclasses inherit parent outputs via a lazy `dup`. Remove inherited outputs with `deregister :output, :name`.

```ruby
class ApplicationTask < CMDx::Task
  output :audit_log, required: true
  output :request_id, required: true
end

class LightweightTask < ApplicationTask
  deregister :output, :audit_log, :request_id
end
```

## Schema

```ruby
MyTask.outputs_schema
# => { user: { name: :user, description: "...", required: true, options: {...} } }
```
