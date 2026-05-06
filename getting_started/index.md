# Getting Started

______________________________________________________________________

Note

These docs track `main`. For version-specific docs, see the `docs/` directory in that version's tag.

CMDx is a Ruby framework for building maintainable, observable business logic through composable command objects. It brings structure, consistency, and powerful developer tools to your business processes.

**Common challenges:**

- Inconsistent service object patterns across the codebase
- Opaque control flow makes debugging hard
- Fragile error handling erodes confidence

**What you get:**

- A standardized task contract
- Built-in flow control and error handling
- Composable, reusable workflows
- Structured logging for observability
- Input validation with type coercions

## Requirements

- Ruby: MRI 3.3+ or a compatible JRuby/TruffleRuby release
- Runtime dependencies: `bigdecimal` and `logger` (both stdlib gems on most distributions)

No ActiveSupport or Rails required — Rails integration is opt-in via `CMDx::Railtie`.

## Installation

Add CMDx to your Gemfile:

```sh
gem install cmdx

# - or -

bundle add cmdx
```

## Configuration

For Rails applications, run the following command to generate a global configuration file in `config/initializers/cmdx.rb`.

```bash
rails generate cmdx:install
```

If not using Rails, manually copy the [configuration file](https://github.com/drexed/cmdx/blob/main/lib/generators/cmdx/templates/install.rb).

## Quick Start

A self-contained example you can run in `irb` or a plain Ruby script — no Rails required:

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

From here, layer in features as you need them:

| Need                   | Feature                                                                  | Example                               |
| ---------------------- | ------------------------------------------------------------------------ | ------------------------------------- |
| Type safety on inputs  | [Coercions](https://drexed.github.io/cmdx/inputs/coercions/index.md)     | `coerce: :integer`                    |
| Input constraints      | [Validations](https://drexed.github.io/cmdx/inputs/validations/index.md) | `numeric: { min: 1 }`                 |
| Conditional stops      | [Signals](https://drexed.github.io/cmdx/interruptions/signals/index.md)  | `skip!`, `fail!`                      |
| Multi-task pipelines   | [Workflows](https://drexed.github.io/cmdx/workflows/index.md)            | `include CMDx::Workflow`              |
| Cross-cutting concerns | [Middlewares](https://drexed.github.io/cmdx/middlewares/index.md)        | `register :middleware`                |
| Lifecycle hooks        | [Callbacks](https://drexed.github.io/cmdx/callbacks/index.md)            | `on_success`, `before_execution`      |
| Output contracts       | [Outputs](https://drexed.github.io/cmdx/outputs/index.md)                | `output :user, :token`                |
| Retry policies         | [Retries](https://drexed.github.io/cmdx/retries/index.md)                | `retry_on Net::OpenTimeout, limit: 3` |
| Structured logs        | [Logging](https://drexed.github.io/cmdx/logging/index.md)                | Automatic                             |

## The CERO Pattern

CMDx organizes business logic around the Compose, Execute, React, Observe (CERO, pronounced "zero") pattern.

```
flowchart LR
    Compose --> Execute
    Execute --> React
    Execute -.-> Observe
```

### Compose

Build single-responsibility tasks with typed inputs, validation, and callbacks. Compose them into workflows to assemble larger processes from small, reusable pieces.

```ruby
class AnalyzeMetrics < CMDx::Task
  retry_on Net::OpenTimeout, limit: 3, jitter: :exponential

  on_success :track_analysis_completion!

  required :dataset_id, coerce: :integer, numeric: { min: 1 }

  optional :analysis_type, default: "standard"

  output :result, :analyzed_at

  def work
    if dataset.nil?
      fail!("Dataset not found", code: 404)
    elsif dataset.unprocessed?
      skip!("Dataset not ready for analysis")
    else
      context.result = PValueAnalyzer.execute(dataset:, analysis_type:)
      context.analyzed_at = Time.now

      SendAnalyzedEmail.execute(user_id: Current.account.manager_id)
    end
  end

  private

  def dataset
    @dataset ||= Dataset.find_by(id: dataset_id)
  end

  def track_analysis_completion!
    dataset.update!(analysis_result_id: context.result.id)
  end
end
```

```ruby
class SendAnalyzedEmail < CMDx::Task
  def work
    user = User.find(context.user_id)
    MetricsMailer.analyzed(user).deliver_now
  end
end
```

### Execute

Every task invocation returns a `Result`. Runtime coerces and validates inputs, runs your `work`, handles exceptions, verifies declared outputs, and logs the outcome — automatically.

```ruby
result = AnalyzeMetrics.execute(dataset_id: 42, analysis_type: "bayesian")
```

```ruby
result = AnalyzeMetrics.execute
```

### React

Branch on the result's status (`success?`, `skipped?`, `failed?`) and read values, reasons, or metadata from it. See [Outcomes](https://drexed.github.io/cmdx/outcomes/result/index.md) for the full surface.

```ruby
if result.success?
  puts "Metrics analyzed at #{result.context.analyzed_at}"
elsif result.skipped?
  puts "Skipped: #{result.reason}"
elsif result.failed?
  puts "Failed: #{result.reason} (code #{result.metadata[:code]})"
end
```

### Observe

Every execution emits a structured log line with the chain id, task identity, state, status, reason, metadata, duration, and tags — enough to correlate nested tasks and reconstruct what happened. See [Logging](https://drexed.github.io/cmdx/logging/index.md) for the full field reference.

```text
I, [2026-04-19T18:42:37.000000Z #3784] INFO -- cmdx: cid="018c2b95-b764-7fff-a1d2-..." index=1 root=false type="Task" task=SendAnalyzedEmail tid="018c2b95-c091-..." state="complete" status="success" reason=nil metadata={} duration=347.21 ...

I, [2026-04-19T18:42:37.535000Z #3784] INFO -- cmdx: cid="018c2b95-b764-7fff-a1d2-..." index=0 root=true type="Task" task=AnalyzeMetrics tid="018c2b95-b764-..." state="complete" status="success" reason=nil metadata={} duration=1872.04 ...
```

Note

With a durable log sink, these lines double as event sourcing — a time-ordered history of every task execution.

## Task Lifecycle

Every `Task.execute` runs the same orchestrated lifecycle. The diagram below traces the path from invocation to a frozen `Result`, including how signals (`success!` / `skip!` / `fail!` / `throw!`) and exceptions interleave with middlewares, callbacks, retries, and rollback.

```
flowchart TD
    Invoke([Task.execute]) --> Dep{Deprecation?}
    Dep -->|":error"| Raise([raise DeprecationError])
    Dep -->|"none / :log / :warn"| Setup["Middlewares + before_execution<br/>+ before_validation + around_execution<br/>+ resolve inputs"]
    Setup --> Work["work (wrapped in retry_on)"]
    Work -->|"success! / skip!"| Verify[Verify outputs]
    Work -->|"fail! / throw! / StandardError"| Rollback{"#rollback?"}
    Work -.->|"raises Fault"| Rollback
    Rollback -->|yes| Cb["after_execution<br/>+ on_state / on_status / on_ok / on_ko"]
    Rollback -->|no| Cb
    Verify --> Cb
    Cb --> Finalize["Finalize Result + Chain<br/>emit :task_executed, freeze & teardown"]
    Finalize --> Out([Frozen Result])
```

Key invariants:

- **Middlewares wrap everything inside `execute`** — telemetry, deprecation, callbacks, work, rollback, and result finalization all happen inside the middleware chain.
- **Retry only wraps `work`** — input resolution and output verification run exactly once, outside the retry loop.
- **Rollback only runs on failure**, before result finalization, so `Result#rolled_back?` is already known when `on_failed` callbacks and `:task_executed` telemetry fire.
- **Teardown always runs** (via `ensure`), freezing the context/errors and clearing the fiber-local chain even when `execute!` re-raises.

## Domain Driven Design

CMDx makes business processes explicit and structural — a natural fit for Domain Driven Design (DDD).

- **Ubiquitous Language:** Task names like `ApproveLoan` or `ShipOrder` mirror the language of domain experts.
- **Bounded Contexts:** Namespaces enforce boundaries — `Billing::GenerateInvoice` and `Shipping::GenerateLabel` keep logic within their domains.
- **Rich Domain Layer:** Move orchestration out of Controllers and ActiveRecord models. Entities hold state; tasks hold behavior. Business logic stays testable and isolated.

## Task Generator

Generate new CMDx tasks quickly using the built-in generator:

```bash
# Task
rails generate cmdx:task ModerateBlogPost

# Workflow
rails generate cmdx:workflow ProcessNotifications

# Namespaced
rails generate cmdx:task Admin::AuditUser
# => Creates app/tasks/admin/audit_user.rb
```

This creates a new task file with the basic structure:

```ruby
# app/tasks/moderate_blog_post.rb
class ModerateBlogPost < CMDx::Task
  def work
    # Your logic here...
  end
end
```

The generator inherits from `ApplicationTask` if defined, falling back to `CMDx::Task`. Define an `ApplicationTask` base class to share configuration across all tasks:

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

Use **present tense verbs + noun** for task names, eg: `ModerateBlogPost`, `ScheduleAppointment`, `ValidateDocument`

## Documentation & Editor Support

The codebase ships with comprehensive YARD annotations on every public class, method, and option. Combined with the structured DSL (`required`, `optional`, `output`, `coerce:`, `validate:`, `on_success`, ...), this gives you:

- **Self-documenting tasks** — declared inputs and outputs read like a contract
- **IDE awareness** — autocomplete and inline docs in editors that consume YARD (Solargraph, RubyMine, etc.)
- **Generated reference** — run `bundle exec yard doc` (or browse [the published docs](https://drexed.github.io/cmdx/api/index.html))
