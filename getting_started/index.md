# Getting Started

______________________________________________________________________

Note

These docs follow `main`. If you are on an older gem version, open the `docs/` folder from that release’s tag so examples match what you run.

Welcome. **CMDx** is a small Ruby framework that helps you write business logic as clear, reusable **tasks**—think “one job per class,” with inputs checked for you, errors handled in a predictable way, and logs that tell a story when things go wrong.

If you have ever opened a “service object” file and wondered *what actually runs, in what order, and what happens on error*, CMDx is meant to calm that chaos.

**Sound familiar?**

- Every team invents its own “service” pattern, so nothing feels the same from file to file.
- When something breaks, it is hard to follow the path the code took.
- Error handling is inconsistent, so you stop trusting the happy path.

**What CMDx gives you instead:**

- One clear contract: how you declare inputs, run work, and read the outcome.
- Built-in flow control (success, skip, fail) so branches are explicit, not hidden.
- Workflows that chain tasks without spaghetti.
- Structured logging so you can see what ran, how long it took, and why it stopped.
- Input validation and type coercion so bad data fails fast with useful messages.

## Requirements

- **Ruby:** MRI 3.3+ (or a recent JRuby / TruffleRuby that matches)
- **Gems:** `bigdecimal` and `logger` (stdlib gems on most setups)

You do **not** need Rails. If you use Rails, there is an optional hook (`CMDx::Railtie`) so integration is a choice, not a requirement.

## Installation

Pick one:

```sh
gem install cmdx

# - or -

bundle add cmdx
```

## Configuration

**Rails:** generate an initializer so you have one place for global settings:

```bash
rails generate cmdx:install
```

That drops `config/initializers/cmdx.rb` into your app.

**Not on Rails:** copy the same template by hand from the repo: [install.rb template](https://github.com/drexed/cmdx/blob/main/lib/generators/cmdx/templates/install.rb).

## Quick Start

Below is a tiny task you can paste into `irb` or a scratch Ruby file—no framework required. It says hello when the name is present, and complains politely when it is not.

```ruby
require "cmdx"

class Greet < CMDx::Task
  required :name, coerce: :string, presence: true

  def work
    context.greeting = "Hello, #{name}!"
  end
end

result = Greet.execute(name: "World")
result.success?          #=> true
result.context.greeting  #=> "Hello, World!"

result = Greet.execute(name: "")
result.failed?           #=> true
result.reason            #=> "name cannot be empty"
result.errors.to_h       #=> { name: ["cannot be empty"] }
```

For how tasks fit together in your head—**CERO** and the full execution pipeline—read [Fundamentals](https://drexed.github.io/cmdx/fundamentals/index.md).

When you are ready to go deeper, this map points you at the right doc:

| You want…                                | Read…                                                                               | Quick idea                                                                                 |
| ---------------------------------------- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| Mental model + lifecycle                 | [Fundamentals](https://drexed.github.io/cmdx/fundamentals/index.md)                 | CERO; [task lifecycle](https://drexed.github.io/cmdx/fundamentals/#task-lifecycle) diagram |
| Global defaults                          | [Configuration](https://drexed.github.io/cmdx/configuration/index.md)               | `CMDx.configure { ... }`                                                                   |
| One class, one job                       | [Setup](https://drexed.github.io/cmdx/basics/setup/index.md)                        | `class Foo < CMDx::Task`                                                                   |
| `required` / `optional` inputs           | [Definitions](https://drexed.github.io/cmdx/inputs/definitions/index.md)            | `required :id, coerce: :integer`                                                           |
| Safer input types                        | [Coercions](https://drexed.github.io/cmdx/inputs/coercions/index.md)                | `coerce: :integer`                                                                         |
| Rules on values                          | [Validations](https://drexed.github.io/cmdx/inputs/validations/index.md)            | `numeric: { min: 1 }`                                                                      |
| Values when omitted                      | [Defaults](https://drexed.github.io/cmdx/inputs/defaults/index.md)                  | `optional :tier, default: "free"`                                                          |
| Data in and out of `work`                | [Context](https://drexed.github.io/cmdx/basics/context/index.md)                    | `context.greeting = ...`                                                                   |
| `.execute` vs `.execute!`                | [Execution](https://drexed.github.io/cmdx/basics/execution/index.md)                | Result object vs raise                                                                     |
| What happened?                           | [Result](https://drexed.github.io/cmdx/outcomes/result/index.md)                    | `success?`, `reason`, `errors`                                                             |
| Stop early on purpose                    | [Signals](https://drexed.github.io/cmdx/interruptions/signals/index.md)             | `skip!`, `fail!`                                                                           |
| Failures as exceptions                   | [Faults](https://drexed.github.io/cmdx/interruptions/faults/index.md)               | `Task.execute!`                                                                            |
| Declared outputs                         | [Outputs](https://drexed.github.io/cmdx/outputs/index.md)                           | `output :user, :token`                                                                     |
| Several tasks in a row                   | [Workflows](https://drexed.github.io/cmdx/workflows/index.md)                       | `include CMDx::Workflow`                                                                   |
| Who called whom                          | [Chain](https://drexed.github.io/cmdx/basics/chain/index.md)                        | `cid` / `tid` in logs                                                                      |
| Cross-cutting stuff (timing, auth, etc.) | [Middlewares](https://drexed.github.io/cmdx/middlewares/index.md)                   | `register :middleware`                                                                     |
| Hooks around run                         | [Callbacks](https://drexed.github.io/cmdx/callbacks/index.md)                       | `on_success`, `before_execution`                                                           |
| Automatic retries                        | [Retries](https://drexed.github.io/cmdx/retries/index.md)                           | `retry_on Net::OpenTimeout, limit: 3`                                                      |
| Cap how often a task runs                | [Rate limit](https://drexed.github.io/cmdx/rate_limit/index.md)                     | `rate_limit :email, max: 5, per: 60`                                                       |
| At-most-once side effects                | [Idempotency](https://drexed.github.io/cmdx/idempotency/index.md)                   | `idempotent_by :payment_id`                                                                |
| One worker at a time                     | [Locks](https://drexed.github.io/cmdx/locks/index.md)                               | `lock_with :account_id`                                                                    |
| Protect flaky dependencies               | [Circuit breaker](https://drexed.github.io/cmdx/circuit_breaker/index.md)           | `circuit_breaker threshold: 3`                                                             |
| Redis / memory backing                   | [Stores](https://drexed.github.io/cmdx/stores/index.md)                             | `config.store = Stores::Redis.new(...)`                                                    |
| What got logged                          | [Logging](https://drexed.github.io/cmdx/logging/index.md)                           | Built-in structured lines                                                                  |
| RSpec patterns                           | [Testing](https://drexed.github.io/cmdx/testing/index.md)                           | `be_success`, `be_failed` matchers                                                         |
| Translated error messages                | [Internationalization](https://drexed.github.io/cmdx/internationalization/index.md) | Locale YAML under `cmdx`                                                                   |

## Task generator

Rails ships generators so you are not copy-pasting boilerplate:

```bash
# Task
rails generate cmdx:task ModerateBlogPost

# Workflow
rails generate cmdx:workflow ProcessNotifications

# Namespaced
rails generate cmdx:task Admin::AuditUser
# => Creates app/tasks/admin/audit_user.rb
```

You get a starter file like:

```ruby
# app/tasks/moderate_blog_post.rb
class ModerateBlogPost < CMDx::Task
  def work
    # Your logic here...
  end
end
```

If you define `ApplicationTask`, new files inherit from it; otherwise they inherit `CMDx::Task`. Handy for shared retries, logging, or request context:

```ruby
# app/tasks/application_task.rb
class ApplicationTask < CMDx::Task
  retry_on Net::OpenTimeout, Net::ReadTimeout, limit: 3, jitter: :exponential

  before_execution :set_request_context

  private

  def set_request_context
    context.request_id ||= SecureRandom.uuid
  end
end
```

Tip

Name tasks like **verb + thing**: `ModerateBlogPost`, `ScheduleAppointment`, `ValidateDocument`. Your future self will thank you in `grep`.

## Documentation and editor help

Public APIs in the gem are documented with YARD. Together with the DSL (`required`, `optional`, `output`, `coerce:`, `validate:`, `on_success`, …) you get:

- **Readable task definitions** — the top of a class lists its contract at a glance.
- **Editor hints** — Solargraph, RubyMine, and friends can show docs inline.
- **A generated book** — run `bundle exec yard doc` locally or browse [the published API docs](https://drexed.github.io/cmdx/api/index.html).

If something in this guide felt fast, read [Fundamentals](https://drexed.github.io/cmdx/fundamentals/index.md) next, then pick a link from the table above—you are already on the right track.
