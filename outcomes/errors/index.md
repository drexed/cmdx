# Outcomes - Errors

**`CMDx::Errors`** is each task’s junk drawer for validation-style messages—usually one key per attribute. Validators, coercions, output checks, and hand-rolled `errors.add(...)` calls all land here. If this drawer is **not** empty when Runtime checks it, you get a failed signal.

Note

`task.errors` and `result.errors` point at the **same** object. After teardown, Runtime freezes `Errors` with the task and context—so the container, its hash, and each message `Set` stay put.

## Access

Inside `work`, use the `errors` reader (or `task.errors` from outside). After the run, the frozen result exposes the same bag:

```ruby
class CreateUser < CMDx::Task
  required :email, :password

  def work
    errors.add(:email, "already taken") if User.exists?(email: email)
    errors.add(:email, "must be verified") unless email_verified?(email)
  end
end

result = CreateUser.execute(email: "taken@example.com", password: "secret")

result.failed?        #=> true
result.errors.to_h    #=> { email: ["already taken", "must be verified"] }
result.errors.frozen? #=> true
```

## API

**Writing**

| Method                  | What it does                                                                                    |
| ----------------------- | ----------------------------------------------------------------------------------------------- |
| `add(key, message)`     | Adds a message under `key`. Duplicate strings for the same key are ignored (backed by a `Set`). |
| `errors[key] = message` | Same as `add`.                                                                                  |
| `merge!(other)`         | Pulls every `(key, message)` from another `Errors` (or anything `#to_hash`-able) into this one. |
| `delete(key)`           | Drops the key; returns the removed `Set` or `nil`.                                              |
| `clear`                 | Empties everything. After teardown, this raises `FrozenError`.                                  |

**Reading**

| Method                           | What you get                                                         |
| -------------------------------- | -------------------------------------------------------------------- |
| `errors[key]`                    | `Array<String>` for that key, or a frozen empty array if none.       |
| `errors.added?(key, message)`    | `true` if that exact string lives under `key`.                       |
| `errors.key?(key)` / `for?(key)` | `true` if the key has at least one message.                          |
| `errors.keys`                    | Keys with messages, in insertion order.                              |
| `errors.empty?`                  | `true` when nothing was recorded.                                    |
| `errors.size`                    | How many keys have messages.                                         |
| `errors.count`                   | Total messages across all keys.                                      |
| `errors.each`                    | Yields `[Symbol, Set<String>]`. `each_key` / `each_value` exist too. |
| `errors.as_json`                 | Alias for `to_h` (Rails-friendly).                                   |
| `errors.to_json`                 | Serializes `to_h` via stdlib `json` (Symbol keys → strings).         |

```ruby
def work
  errors.add(:amount, "must be positive") if amount.negative?
  errors[:amount] = "cannot exceed daily limit" if amount > 10_000

  # Pull in a child task’s errors without stomping your own
  sub = ValidateAddress.execute(address: context.address)
  errors.merge!(sub.errors) if sub.failed?
end
```

Because `Errors` mixes in `Enumerable`, all the usual goodies work (`any?`, `select`, `find`, `group_by`, `partition`, …):

```ruby
result.errors.any? { |_key, set| set.size > 1 } # keys with multiple messages
result.errors.select { |key, _set| key.to_s.start_with?("address_") }
```

## Rendering

```ruby
class ConfigureServer < CMDx::Task
  required :hostname, :port, coerce: :integer
end

result = ConfigureServer.execute(port: "abc")

result.errors.to_h
#=> { hostname: ["is required"], port: ["could not coerce into an integer"] }

result.errors.full_messages
#=> { hostname: ["hostname is required"],
#     port:     ["port could not coerce into an integer"] }

result.errors.to_s
#=> "hostname is required. port could not coerce into an integer"

result.reason == result.errors.to_s #=> true
```

`to_hash` mirrors `to_h` by default and `full_messages` when you pass `true`.

## Pattern matching

Ruby 3.0+ can pattern-match `Errors` too.

```ruby
result = CreateUser.execute(email: "taken@example.com")

case result.errors
in { email: [String => first, *] }
  notify_user(first)
in { base: messages } if messages.any?
  render_flash(messages)
end
```

`deconstruct_keys(nil)` is the full `to_h` (`{ key => [messages] }`); a key list slices it. `deconstruct` yields `[[key, messages], ...]` for find-style matches.

## Failure propagation

Runtime peeks at `task.errors.empty?` three times: after inputs resolve, after `work` returns, and after outputs are verified. Any time the bag is not empty, it throws a failed signal with `reason` = `errors.to_s` and `metadata` = `task.metadata`.

```
flowchart LR
  Resolve[Resolve inputs] --> C1{errors.empty?}
  C1 -->|no| Fail["throw Signal.failed<br/>reason = errors.to_s<br/>metadata = task.metadata"]
  C1 -->|yes| Work[work]
  Work --> C2{errors.empty?}
  C2 -->|no| Fail
  C2 -->|yes| Verify[Verify outputs]
  Verify --> C3{errors.empty?}
  C3 -->|no| Fail
  C3 -->|yes| Ok[Signal.success]
```

Under the hood that is `Runtime#signal_errors!` at each gate.

Surprise for newcomers

Adding errors inside `work` does **not** stop the method on the spot—the throw happens **after** `work` returns (and again after output verification). Need to bail immediately? Use `fail!(...)`.

## Freeze semantics

```ruby
result = CreateUser.execute(email: "")

result.errors.frozen?                  #=> true
result.errors.messages.frozen?         #=> true
result.errors.messages[:email].frozen? #=> true   (the underlying Set)
result.errors[:email].frozen?          #=> false  (#[] returns a fresh Array via Set#to_a)
result.errors.add(:x, "y")             #=> raises FrozenError
```

`Errors#freeze` deep-freezes each message `Set` before freezing the wrapper.

## See also

- [Inputs — validations](https://drexed.github.io/cmdx/inputs/validations/index.md) — validators that fill `errors` for you.
- [Inputs — coercions](https://drexed.github.io/cmdx/inputs/coercions/index.md) — coercion failures show up here.
- [Outputs](https://drexed.github.io/cmdx/outputs/index.md) — output verification errors use the same bucket.
- [v1 → v2 migration](https://drexed.github.io/cmdx/v2-migration/#errors) — what changed for `Errors` in 2.0.
