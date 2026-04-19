---
date: 2026-04-15
authors:
  - drexed
categories:
  - Tutorials
slug: cmdx-patterns-defensive-contracts
---

# CMDx Patterns: Defensive Contracts

*Part 1 of the CMDx Patterns series*

*Targets CMDx v1.21.*

I have a rule when building Ruby tasks: if a task can be misused, it will be misused. Not out of malice—out of haste, incomplete documentation, or the natural entropy of a growing codebase. Someone passes a string where you expected an integer. Someone forgets to read the context key you set. Someone calls your task from a new workflow and the whole pipeline falls over because the inputs were subtly wrong.

Defensive contracts are CMDx's answer to this. By combining `required`/`optional` attributes, validations, coercions, and `returns`, you build tasks that are impossible to misuse silently. Bad data fails loudly at the boundary. Missing outputs fail immediately at the source. The contract is the code, and the code enforces itself.

<!-- more -->

## The Three Layers

A defensive contract has three layers, each catching problems at a different point in execution:

1. **Input validation** — `required`/`optional` with types and validators catch bad data *before* `work` runs
2. **Business logic guards** — `fail!`/`skip!` inside `work` catch domain-specific issues
3. **Output validation** — `returns` catches missing context keys *after* `work` completes

```ruby
class Billing::ChargeCard < CMDx::Task
  # Layer 1: Input validation
  required :customer_id, type: :integer, numeric: { min: 1 }
  required :amount_cents, type: :integer, numeric: { min: 100, max: 1_000_000 }
  required :currency, inclusion: { in: %w[usd eur gbp] }
  optional :idempotency_key, default: -> { SecureRandom.uuid }

  # Layer 3: Output validation
  returns :charge, :receipt_url

  def work
    customer = Customer.find(customer_id)

    # Layer 2: Business logic guards
    fail!("Account suspended", code: :suspended) if customer.suspended?
    fail!("Card expired", code: :card_expired, expired_at: customer.card_expiry) if customer.card_expired?

    context.charge = PaymentGateway.charge(
      customer: customer.gateway_id,
      amount: amount_cents,
      currency: currency,
      idempotency_key: idempotency_key
    )
    context.receipt_url = context.charge.receipt_url
  end
end
```

Each layer fails with structured, specific errors. The caller never gets a cryptic `NoMethodError` three steps downstream.

## Input Contracts: More Than Type Checking

The simplest contract is a `required` attribute. But the real power comes from stacking constraints.

### Presence

Prevent nil and blank values from sneaking through:

```ruby
required :email, presence: true       # rejects nil, "", "   "
required :name, presence: true
optional :nickname                     # nil is fine here
```

### Type Coercion

Coercion runs *before* validation. This means messy inputs from forms, APIs, and CSV imports get cleaned up automatically:

```ruby
required :quantity, type: :integer     # "42" → 42, "abc" → 0
required :price, type: :big_decimal    # "19.99" → BigDecimal("19.99")
required :active, type: :boolean       # "true" → true, "1" → true
required :tags, type: :array           # "ruby" → ["ruby"], "[1,2]" → [1, 2]
optional :scheduled_at, type: :datetime # "2026-03-15" → DateTime
```

### Numeric Ranges

Catch out-of-bounds values before they corrupt data:

```ruby
required :age, type: :integer, numeric: { min: 0, max: 150 }
required :rating, type: :integer, numeric: { within: 1..5 }
required :discount_percent, type: :big_decimal, numeric: { min: 0, max: 100 }
```

### Format Validation

Enforce structure with regex patterns:

```ruby
required :sku, format: /\A[A-Z]{3}-[0-9]{4}\z/
required :phone, format: { with: /\A\+?[1-9]\d{1,14}\z/, message: "must be E.164 format" }
required :slug, format: { without: /\s/, message: "cannot contain whitespace" }
```

### Inclusion and Exclusion

Constrain values to known sets:

```ruby
required :status, inclusion: { in: %w[draft published archived] }
required :priority, inclusion: { in: 1..5 }
optional :role, exclusion: { in: %w[superadmin root], message: "cannot be a system role" }
```

### Length

Guard string boundaries:

```ruby
required :title, length: { min: 1, max: 200 }
required :body, length: { min: 50 }
optional :bio, length: { max: 500 }
required :pin, length: { is: 4 }
```

### Combining Constraints

Stack them all. Each constraint adds a validation rule, and all rules run together:

```ruby
required :username,
  type: :string,
  presence: true,
  length: { min: 3, max: 30 },
  format: { with: /\A[a-zA-Z0-9_]+\z/, message: "only letters, numbers, and underscores" }
```

If multiple validations fail, you get all errors at once:

```ruby
result = CreateAccount.execute(username: "")

result.metadata[:errors][:messages]
#=> {
#     username: [
#       "can't be blank",
#       "is too short (minimum is 3 characters)",
#       "only letters, numbers, and underscores"
#     ]
#   }
```

No back-and-forth "fix this, now fix that." The caller sees everything that's wrong in a single response.

## Custom Validators

Built-in validators cover common cases, but real domains have domain-specific rules. Register your own:

```ruby
class RoutingNumberValidator
  def self.call(value, options = {})
    digits = value.to_s.chars.map(&:to_i)
    unless digits.length == 9 &&
           (3 * (digits[0] + digits[3] + digits[6]) +
            7 * (digits[1] + digits[4] + digits[7]) +
            (digits[2] + digits[5] + digits[8])) % 10 == 0
      raise CMDx::ValidationError, options.fetch(:message, "is not a valid routing number")
    end
  end
end

class Billing::SetupBankAccount < CMDx::Task
  register :validator, :routing_number, RoutingNumberValidator

  required :routing_number, routing_number: true
  required :account_number, presence: true, length: { min: 4, max: 17 }

  def work
    context.bank_account = BankAccount.create!(
      routing_number: routing_number,
      account_number: account_number
    )
  end
end
```

The validator integrates seamlessly—same error format, same metadata structure, same handling patterns.

## Conditional Requirements

Sometimes an attribute is only required under certain conditions:

```ruby
class Shipping::CalculateRate < CMDx::Task
  required :country, inclusion: { in: ISO3166::Country.codes }
  required :weight_kg, type: :big_decimal, numeric: { min: 0.01 }

  optional :state, presence: true, if: :domestic?
  optional :postal_code, format: /\A\d{5}(-\d{4})?\z/, if: :domestic?
  optional :customs_value, type: :big_decimal, numeric: { min: 0 }, unless: :domestic?

  def work
    context.rate = ShippingService.calculate(
      country: country,
      state: state,
      postal_code: postal_code,
      weight: weight_kg,
      customs_value: customs_value
    )
  end

  private

  def domestic?
    country == "US"
  end
end
```

Domestic shipments require state and postal code. International shipments require a customs value. The task validates the right set of rules based on the inputs themselves.

## Output Contracts with Returns

Input validation prevents bad data from entering. Output validation prevents incomplete data from leaving:

```ruby
class Users::Register < CMDx::Task
  required :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  required :password, length: { min: 8 }
  optional :referral_code

  returns :user, :session_token, :welcome_email_job_id

  def work
    context.user = User.create!(email: email, password: password)
    context.session_token = SessionService.create(context.user)
    context.welcome_email_job_id = WelcomeMailer.deliver_later(context.user).job_id

    apply_referral_bonus if referral_code
  end

  private

  def apply_referral_bonus
    Referrals::ApplyBonus.execute(code: referral_code, new_user: context.user)
  end
end
```

If a refactor accidentally removes the `session_token` assignment, the task fails with:

```ruby
result.metadata[:errors][:messages]
#=> { session_token: ["must be set in the context"] }
```

The bug is caught immediately, in the task that caused it, not downstream in the controller that tries to read the token.

## Layered Contracts via Inheritance

For large codebases, build contracts in layers:

```ruby
class ApplicationTask < CMDx::Task
  returns :audit_log
end

class Billing::BaseTask < ApplicationTask
  returns :billing_event

  on_success :emit_billing_event

  private

  def emit_billing_event
    BillingEvents.publish(context.billing_event) if context.billing_event
  end
end

class Billing::ChargeCard < Billing::BaseTask
  required :customer_id, type: :integer
  required :amount_cents, type: :integer, numeric: { min: 100 }

  returns :charge

  def work
    context.charge = PaymentGateway.charge(customer_id, amount_cents)
    context.billing_event = { type: :charge, amount: amount_cents, at: Time.current }
    context.audit_log = "Charged #{amount_cents} to customer #{customer_id}"
  end
end
```

`Billing::ChargeCard` must set three returns: `audit_log` (from `ApplicationTask`), `billing_event` (from `Billing::BaseTask`), and `charge` (its own). Forget any one and the task fails.

For tasks that genuinely don't need a parent's return, opt out explicitly:

```ruby
class HealthCheck < ApplicationTask
  remove_returns :audit_log

  def work
    context.status = :ok
  end
end
```

## Manual Errors for Complex Validation

Sometimes validation logic can't be expressed declaratively. Use the `errors` API for multi-field validation inside `work`:

```ruby
class Events::Create < CMDx::Task
  required :starts_at, type: :datetime
  required :ends_at, type: :datetime
  required :venue_id, type: :integer
  optional :capacity, type: :integer, numeric: { min: 1 }

  returns :event

  def work
    errors.add(:ends_at, "must be after start time") if ends_at <= starts_at
    errors.add(:starts_at, "must be in the future") if starts_at < Time.current
    errors.add(:venue_id, "venue is already booked") if venue_booked?

    fail!("Validation failed") if errors.any?

    context.event = Event.create!(
      starts_at: starts_at, ends_at: ends_at,
      venue_id: venue_id, capacity: capacity
    )
  end

  private

  def venue_booked?
    Event.where(venue_id: venue_id)
         .where("starts_at < ? AND ends_at > ?", ends_at, starts_at)
         .exists?
  end
end
```

The `errors` object collects all issues, then `fail!` halts with a structured payload containing every problem at once.

## The Complete Defensive Task

Pulling it all together, here's what a fully defensive task looks like:

```ruby
class Transfers::Execute < CMDx::Task
  register :validator, :routing_number, RoutingNumberValidator

  required :from_account_id, type: :integer, numeric: { min: 1 }
  required :to_routing_number, routing_number: true
  required :to_account_number, presence: true, length: { min: 4, max: 17 }
  required :amount, type: :big_decimal, numeric: { min: 0.01, max: 250_000 }
  required :currency, inclusion: { in: %w[usd] }
  optional :memo, length: { max: 255 }

  returns :transfer, :confirmation_number

  def work
    from_account = Account.find(from_account_id)

    fail!("Insufficient funds", code: :nsf,
      available: from_account.balance) if from_account.balance < amount

    fail!("Account frozen", code: :frozen,
      frozen_since: from_account.frozen_at) if from_account.frozen?

    context.transfer = TransferService.initiate(
      from: from_account,
      to_routing: to_routing_number,
      to_account: to_account_number,
      amount: amount,
      currency: currency,
      memo: memo
    )
    context.confirmation_number = context.transfer.confirmation_number
  end
end
```

Count the layers of defense:

1. **Type coercion** — Strings become BigDecimals and integers
2. **Presence/length** — Blanks and oversized inputs rejected
3. **Format** — Routing number checksummed via custom validator
4. **Range** — Amount bounded between $0.01 and $250,000
5. **Inclusion** — Currency restricted to known set
6. **Business guards** — Insufficient funds and frozen accounts caught
7. **Returns** — Transfer and confirmation number guaranteed on success

Seven layers, and the caller's code is still just:

```ruby
result = Transfers::Execute.execute(
  from_account_id: 42,
  to_routing_number: "021000021",
  to_account_number: "1234567890",
  amount: "500.00",
  currency: "usd"
)
```

Clean inputs, guaranteed outputs, structured errors. That's a defensive contract.

Happy coding!

## References

- [Attributes - Definitions](https://drexed.github.io/cmdx/attributes/definitions/)
- [Attributes - Validations](https://drexed.github.io/cmdx/attributes/validations/)
- [Attributes - Coercions](https://drexed.github.io/cmdx/attributes/coercions/)
- [Returns](https://drexed.github.io/cmdx/returns/)
