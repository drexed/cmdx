# Outputs

Outputs answer a simple question: **“When this task succeeds, what keys must exist on `context`?”**

You declare those keys up front. After `work` finishes happily, CMDx walks the list: read each key from `context`, apply a default if you configured one and the value is missing or `nil`, and fail the task if something is still missing.

Outputs stay intentionally small. If you need coercion, fancy validation, or nested resolution, use [Inputs](https://drexed.github.io/cmdx/inputs/definitions/index.md) (or plain Ruby after `work`).

## Declaration

`output` and `outputs` are aliases — pick whichever reads nicer in your file.

```ruby
class AuthenticateUser < CMDx::Task
  required :email, :password

  output :source
  output :user, :token

  def work
    context.source = email.include?("@mycompany.com") ? :admin_portal : :user_portal
    context.user   = User.authenticate(email, password)
    context.token  = JwtService.encode(user_id: context.user.id)
  end
end
```

### Options

| Option                         | Default | What it does                                                                                                                       |
| ------------------------------ | ------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `default:`                     | —       | Used when `context[name]` is missing or `nil`. Can be a literal, Symbol (method on task), Proc / callable — same shapes as inputs. |
| `if:` / `unless:`              | —       | Skip checking this output when the predicate says so.                                                                              |
| `description:` (alias `desc:`) | —       | Shows up in `outputs_schema` for docs / introspection.                                                                             |

```ruby
output :report_path
output :exported_at, if: -> { context.persist? }    # Proc: instance_exec on task, no args
output :tracked, if: :persist?                       # Symbol: calls task.persist?
```

### Defaults

Defaults are a nice way to say “if the task did not set this, fill it in for me” without extra noise in `work`.

They run **during verification**, after `work`, whenever the resolved value is `nil` — whether the key was never written or the task explicitly set `nil`.

```ruby
class ComputeRecommendations < CMDx::Task
  output :version, default: "v2"                          # literal
  output :source, default: :default_source                # Symbol → task#default_source
  output :generated_at, default: -> { Time.now }          # Proc → instance_exec on task
  output :tenant, default: TenantDefaults                 # anything responding to #call(task)

  def work
    # Defaults are applied during verification (after work). Assign in work
    # to override a default; leave absent or nil to let the default fill in.
  end

  private

  def default_source = self.class.name
end
```

Curious about every default shape in detail? [Inputs - Defaults](https://drexed.github.io/cmdx/inputs/defaults/index.md) spells it out — **same rules** as here.

## Removals

Subclasses inherit outputs like everything else. `deregister` drops keys you do not want anymore:

```ruby
class ApplicationTask < CMDx::Task
  output :audit_log
  output :request_id
end

class LightweightTask < ApplicationTask
  deregister :output, :audit_log, :request_id

  def work
    # No longer required to set context.audit_log or context.request_id
  end
end
```

## Verification Behavior

Verification is the “did we leave the kitchen clean?” step. It runs **after** `work` completes **without** throwing `skip!`, `fail!`, or `throw!`.

```
flowchart LR
    W[work] --> R{signal thrown?}
    R -->|skip! / fail! / throw!| Done[Skip output verification]
    R -->|no| V[Verify each output]
    V --> E{errors?}
    E -->|no| S[Signal.success]
    E -->|yes| F[Signal.failed reason=errors.to_s]
```

For each output, in declaration order:

1. If `:if` / `:unless` says “skip,” done with this one.
1. Otherwise read `context[name]`.
1. If it is `nil`, try `:default`.
1. Still nothing? That is a missing output (`cmdx.outputs.missing`).
1. Otherwise write the resolved value back to `context[name]`.

Those errors show up like any other validation failure: `result.reason`, `result.errors`, and under `execute!` they become `CMDx::Fault`.

### Missing Output

```ruby
class CreateUser < CMDx::Task
  output :user

  def work
    # Forgot to set context.user
  end
end

result = CreateUser.execute
result.failed?         #=> true
result.reason          #=> "user must be set in the context"
result.errors.to_h     #=> { user: ["must be set in the context"] }
```

### With Bang Execution

`execute!` turns the same failure into an exception you can rescue:

```ruby
begin
  CreateUser.execute!
rescue CMDx::Fault => e
  e.message                #=> "user must be set in the context"
  e.result.errors[:user]   #=> ["must be set in the context"]
  e.task                   #=> CreateUser (the failing task class)
end
```

## Schema Introspection

`Task.outputs_schema` is your machine-readable cheat sheet — handy for docs generators or admin UIs:

```ruby
class CreateUser < CMDx::Task
  output :user, description: "the persisted user"
end

CreateUser.outputs_schema
# => { user: { name: :user,
#              description: "the persisted user",
#              options: { description: "the persisted user" } } }
```
