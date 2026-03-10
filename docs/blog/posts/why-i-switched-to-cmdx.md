---
date: 2026-03-18
authors:
  - drexed
categories:
  - Tutorials
slug: why-i-switched-to-cmdx
---

# Why I Switched to CMDx (and How You Can Too)

If you've been writing Ruby long enough, you've probably used at least one service object gem. Maybe you started with Interactor back when it was the default choice. Maybe you moved to ActiveInteraction for its ActiveModel-like validations. Maybe you tried Actor or LightService. I've used all of them in production, and each one taught me something about what I actually need from a command framework.

This isn't a hit piece on any of those gems—they're well-built tools that solve real problems. But after years of using them, I kept hitting the same walls. So I built CMDx to knock those walls down.

<!-- more -->

## The Walls I Kept Hitting

Before we get into specifics, let me describe the pattern I kept running into across projects and frameworks:

1. **Something breaks in production.** I check the logs. Nothing useful. The service object ran, but I have no idea what it did, what data it received, or why it failed.

2. **A new developer joins the team.** They look at our service objects and ask: "What does this return? A boolean? A hash? An object?" The answer is "it depends on who wrote it."

3. **We need to add retries to an API call.** Now we're wrapping our service object in a retry loop, adding a circuit breaker gem, and the original 20-line class is 80 lines of infrastructure.

4. **We need to compose services.** The framework's organizer/pipeline works great until you need conditional steps, parallel execution, or failure tracing across the chain.

Sound familiar? Let me show you what each framework looks like side-by-side with CMDx.

## Interactor: The Pioneer

Interactor popularized the pattern in Ruby. Simple, minimal, effective:

```ruby
# Interactor
class AuthenticateUser
  include Interactor

  def call
    user = User.find_by(email: context.email)

    if user&.authenticate(context.password)
      context.user = user
      context.token = generate_token(user)
    else
      context.fail!(message: "Invalid credentials")
    end
  end
end

result = AuthenticateUser.call(email: "ada@example.com", password: "secret")
result.success? #=> true
result.user     #=> #<User ...>
```

And here's the same thing in CMDx:

```ruby
# CMDx
class AuthenticateUser < CMDx::Task
  required :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  required :password, presence: true

  returns :user, :token

  def work
    user = User.find_by(email: email)

    if user&.authenticate(password)
      context.user = user
      context.token = generate_token(user)
    else
      fail!("Invalid credentials", code: :auth_failed)
    end
  end
end

result = AuthenticateUser.execute(email: "ada@example.com", password: "secret")
result.success?      #=> true
result.context.user  #=> #<User ...>
```

At first glance, they look similar. But look at what CMDx adds for free:

- **Typed, validated inputs** — `email` must match a format, `password` can't be blank. With Interactor, you'd need to validate manually inside `call`.
- **Declared outputs** — `returns :user, :token` guarantees these exist after success. Forget to set `context.token`? Automatic failure.
- **Structured failure metadata** — `code: :auth_failed` ships with the result. With Interactor, you get a message string and nothing else.
- **Automatic logging** — Every execution is logged with timing, chain ID, and outcome. Interactor logs nothing.

### Migrating Organizers

Interactor's `Organizer` maps to CMDx's `Workflow`:

```ruby
# Interactor
class PlaceOrder
  include Interactor::Organizer

  organize ValidateCart, ChargeCard, SendReceipt
end

# CMDx
class PlaceOrder < CMDx::Task
  include CMDx::Workflow

  settings workflow_breakpoints: ["failed"]

  task ValidateCart
  task ChargeCard
  task SendReceipt
end
```

The CMDx version adds conditional execution (`if:`, `unless:`), breakpoint control, and chain correlation across every step.

## ActiveInteraction: The Validator

ActiveInteraction leans heavily on ActiveModel conventions. If you love `validates` DSL, it feels like home:

```ruby
# ActiveInteraction
class CreateProject < ActiveInteraction::Base
  string :name
  integer :budget
  string :description, default: nil

  validates :name, presence: true
  validates :budget, numericality: { greater_than: 0 }

  def execute
    Project.create!(name: name, budget: budget, description: description)
  end
end

outcome = CreateProject.run(name: "Alpha", budget: 5000)
outcome.valid? #=> true
outcome.result #=> #<Project ...>
```

The CMDx equivalent:

```ruby
# CMDx
class CreateProject < CMDx::Task
  required :name, presence: true
  required :budget, type: :integer, numeric: { min: 1 }
  optional :description

  def work
    context.project = Project.create!(name: name, budget: budget, description: description)
  end
end

result = CreateProject.execute(name: "Alpha", budget: 5000)
result.success?         #=> true
result.context.project  #=> #<Project ...>
```

ActiveInteraction requires `activemodel` as a dependency. CMDx has zero dependencies. But the bigger difference is what happens *beyond* validation:

| Capability | ActiveInteraction | CMDx |
|---|---|---|
| Type coercion | ✅ (via filters) | ✅ (20+ built-in coercers) |
| Validation | ✅ (ActiveModel) | ✅ (built-in, no dependency) |
| Logging | ❌ | ✅ (automatic, structured) |
| Correlation IDs | ❌ | ✅ (chain_id across workflows) |
| Middleware | ❌ | ✅ (timeout, transactions, etc.) |
| Retries | ❌ | ✅ (with jitter, selective retry) |
| Dry run | ❌ | ✅ |

ActiveInteraction is excellent at input processing. CMDx handles the full lifecycle.

## LightService: The Pipeliner

LightService shines at composing actions into sequences:

```ruby
# LightService
class PlaceOrder
  extend LightService::Organizer

  def self.call(user:, items:)
    with(user: user, items: items).reduce(
      ValidateCart,
      CreateOrder,
      ChargePayment,
      SendConfirmation
    )
  end
end

class ValidateCart
  extend LightService::Action

  expects :items
  promises :cart_total

  executed do |ctx|
    ctx.fail!("Cart is empty") if ctx.items.empty?
    ctx.cart_total = ctx.items.sum { |i| i[:price] }
  end
end
```

In CMDx:

```ruby
# CMDx
class PlaceOrder < CMDx::Task
  include CMDx::Workflow

  settings workflow_breakpoints: ["failed"]

  task ValidateCart
  task CreateOrder
  task ChargePayment
  task SendConfirmation, if: :order_confirmed?

  private

  def order_confirmed?
    context.order&.confirmed?
  end
end

class ValidateCart < CMDx::Task
  required :items, type: :array, presence: true

  returns :cart_total

  def work
    context.cart_total = items.sum { |i| i[:price] }
  end
end
```

LightService's `expects`/`promises` maps to CMDx's `required`/`returns`, but CMDx adds type coercion, validation, and automatic enforcement. LightService does support middleware (called "organizer hooks"), but CMDx's middleware system is more flexible—you can register them globally, per-task, and they compose with `yield`.

## The Migration Playbook

Switching frameworks doesn't have to be a big-bang rewrite. Here's how I've done it on real projects:

### Step 1: Add CMDx Alongside Your Existing Gem

```ruby
# Gemfile
gem "interactor"  # keep existing
gem "cmdx"        # add new
```

Both can coexist. No conflicts.

### Step 2: Write New Features with CMDx

Don't rewrite existing code. Start fresh with new features:

```ruby
# New feature? Use CMDx
class Subscriptions::Renew < CMDx::Task
  required :subscription_id, type: :integer
  required :payment_method_id, type: :integer

  returns :renewal

  def work
    subscription = Subscription.find(subscription_id)
    context.renewal = subscription.renew!(payment_method_id: payment_method_id)
  end
end
```

### Step 3: Migrate High-Value Paths First

Pick the service objects that cause the most production pain—the ones you're always debugging. Migrate those first and immediately benefit from structured logging and chain correlation.

### Step 4: Cheat Sheet

| Interactor | ActiveInteraction | LightService | CMDx |
|---|---|---|---|
| `include Interactor` | `< ActiveInteraction::Base` | `extend LightService::Action` | `< CMDx::Task` |
| `def call` | `def execute` | `executed do` | `def work` |
| `context.fail!` | `errors.add` | `ctx.fail!` | `fail!` |
| `context.key` | `key` (accessor) | `ctx.key` | `context.key` or `key` (with attrs) |
| `Organizer` | `compose` | `Organizer` | `include CMDx::Workflow` |
| N/A | N/A | N/A | `returns :key` |
| N/A | N/A | N/A | `skip!` |
| N/A | N/A | N/A | `dry_run?` |

## What You Gain

After migrating several projects, here's what consistently improved:

- **Debugging time dropped dramatically.** Chain correlation means I can trace any request across every task it touched. No more log archaeology.

- **Onboarding got easier.** New developers read a task's `required`/`optional`/`returns` declarations and understand the contract immediately. The code is self-documenting.

- **Fewer production surprises.** Type coercion catches data issues at the boundary. Returns catch missing outputs. Middlewares handle cross-cutting concerns consistently.

- **Less infrastructure code.** Retries, timeouts, and logging are built-in. I deleted hundreds of lines of hand-rolled retry loops and logging wrappers.

You don't have to migrate everything at once. Start with one task, see how it feels, and let the results speak for themselves.

Happy coding!

## References

- [Comparison](https://drexed.github.io/cmdx/comparison/)
- [Getting Started](https://drexed.github.io/cmdx/getting_started/)
- [Attributes](https://drexed.github.io/cmdx/attributes/definitions/)
- [Returns](https://drexed.github.io/cmdx/returns/)
