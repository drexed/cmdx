---
date: 2026-05-20
authors:
  - drexed
categories:
  - Tutorials
slug: real-world-cmdx-user-onboarding
---

# Real-World CMDx: Building a User Onboarding Pipeline

*Part 1 of the Real-World CMDx series*

*Built on CMDx 2.0 — see the [v2 release post](cmdx-v2-the-runtime-rewrite.md) for the runtime changes this post depends on.*

User onboarding is one of those features that sounds simple until you actually build it. "Just create a user and send them an email." Sure—until you add email verification, trial activation, referral tracking, welcome sequences, analytics events, and a dozen conditional paths based on plan type, invite status, and geographic regulations.

I've built this feature in Ruby at least six times across different projects, and it always follows the same trajectory: starts as a single service object, grows tentacles, and eventually becomes the thing nobody wants to touch. This time, I'm building it with CMDx from the start—decomposed into focused tasks, orchestrated as a workflow, with full observability baked in.

<!-- more -->

## The Requirements

Here's what our onboarding pipeline needs to do:

1. **Register** the user (validate inputs, create the record)
2. **Send verification email** (with a signed token)
3. **Activate trial** (if the plan includes one)
4. **Apply referral bonus** (if a referral code was provided)
5. **Send welcome email** (different content for trial vs paid users)
6. **Track analytics** (registration event with attribution data)

Some of these steps are conditional. Some can fail without killing the whole pipeline. Let's build it piece by piece.

## Starting with the Tasks

Every good workflow starts with small, focused tasks. Each one does exactly one thing.

### Register the User

```ruby
class Users::Register < CMDx::Task
  required :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  required :password, length: { min: 8 }
  required :plan, inclusion: { in: %w[free trial professional enterprise] }
  optional :referral_code
  optional :invite_token

  output :user, required: true

  def work
    fail!("Email already taken", code: :duplicate) if User.exists?(email: email)

    context.user = User.create!(
      email: email,
      password: password,
      plan: plan,
      status: :pending_verification
    )
  end
end
```

Three layers of defense here: input validations catch malformed inputs, the `fail!` catches business rule violations, and `output :user, required: true` guarantees downstream tasks always have the user available — Runtime verifies it's present after `work` returns and fails the task otherwise.

### Send Verification Email

```ruby
class Users::SendVerification < CMDx::Task
  required :user

  output :verification_token, required: true

  def work
    context.verification_token = user.generate_verification_token!

    UserMailer.verification(
      user: user,
      token: context.verification_token
    ).deliver_later
  end
end
```

### Activate Trial

This task only runs for trial plans. That conditional logic lives in the workflow—the task itself doesn't know or care:

```ruby
class Users::ActivateTrial < CMDx::Task
  required :user

  output :trial_ends_at, required: true

  def work
    trial_duration = case user.plan
                     when "trial" then 14.days
                     when "professional" then 30.days
                     else 0.days
                     end

    skip!("Plan has no trial period") if trial_duration.zero?

    user.update!(
      trial_started_at: Time.current,
      trial_ends_at: Time.current + trial_duration
    )
    context.trial_ends_at = user.trial_ends_at
  end
end
```

Notice the `skip!` — if somehow the task gets called for a plan without a trial, it skips gracefully rather than creating a zero-length trial. Belt and suspenders.

### Apply Referral Bonus

```ruby
class Users::ApplyReferralBonus < CMDx::Task
  required :user
  required :referral_code, presence: true

  def work
    referrer = User.find_by(referral_code: referral_code)

    if referrer.nil?
      fail!("Invalid referral code", code: :invalid_referral)
    end

    Referral.create!(
      referrer: referrer,
      referred: user,
      bonus_type: :signup,
      status: :pending
    )

    referrer.increment!(:referral_count)
    logger.info "Referral bonus applied: #{referrer.email} → #{user.email}"
  end
end
```

### Send Welcome Email

Different content based on plan type:

```ruby
class Users::SendWelcome < CMDx::Task
  required :user

  def work
    template = case user.plan
               when "trial", "professional" then :welcome_trial
               when "enterprise" then :welcome_enterprise
               else :welcome_free
               end

    UserMailer.welcome(user: user, template: template).deliver_later
  end
end
```

### Track Analytics

```ruby
class Users::TrackRegistration < CMDx::Task
  required :user
  optional :referral_code

  settings(tags: ["analytics", "onboarding"])

  def work
    Analytics.track("user_registered",
      user_id: user.id,
      plan: user.plan,
      referral: referral_code.present?,
      source: context.utm_source,
      timestamp: Time.current
    )
  end
end
```

## The Workflow

Now we compose these tasks into a pipeline:

```ruby
class Users::Onboard < CMDx::Task
  include CMDx::Workflow

  settings(tags: ["onboarding"])

  task Users::Register
  task Users::SendVerification
  task Users::ActivateTrial, if: :trial_plan?
  task Users::ApplyReferralBonus, if: :has_referral?
  task Users::SendWelcome
  task Users::TrackRegistration

  private

  def trial_plan?
    %w[trial professional].include?(context.plan)
  end

  def has_referral?
    context.referral_code.present?
  end
end
```

Read that top-to-bottom. Even someone unfamiliar with the codebase can see the onboarding flow at a glance. That's the storytelling pattern—the workflow declaration tells the story of what happens when a user signs up.

## Adding Infrastructure

The tasks above handle business logic. Now let's wrap them with infrastructure concerns.

### Base Task with Transaction

```ruby
class ApplicationTask < CMDx::Task
  register :middleware, DatabaseTransaction
  register :middleware, ErrorTracking
end
```

All our tasks inherit from this (update the classes above accordingly), so every mutation is transactional and every exception is reported.

### The Controller

```ruby
class RegistrationsController < ApplicationController
  def create
    result = Users::Onboard.execute(
      email: params[:email],
      password: params[:password],
      plan: params[:plan],
      referral_code: params[:referral_code],
      utm_source: params[:utm_source]
    )

    case result
    in { status: "success" }
      sign_in(result.context.user)
      redirect_to dashboard_path, notice: "Welcome! Check your email to verify your account."
    in { status: "failed", metadata: { code: :duplicate } }
      redirect_to login_path, alert: "An account with that email already exists."
    in { status: "failed" } if result.errors.any?
      @errors = result.errors.to_h
      render :new, status: :unprocessable_entity
    in { status: "failed" }
      redirect_to new_registration_path, alert: result.reason
    end
  end
end
```

Pattern matching makes the controller clean. Each failure type gets a specific response — `metadata[:code]` for tagged business failures, `result.errors` for input/output validation failures, and `result.reason` as the fallback.

## Handling Partial Failures

What happens when the referral code is invalid but everything else succeeds? Right now, the workflow stops at `Users::ApplyReferralBonus` and the user never gets their welcome email.

That might not be what we want. A bad referral code shouldn't block registration.

In v2, failure always halts the pipeline — there's no opt-out toggle. That's correct for `Users::Register` (can't continue without a user) but too strict for referrals. The fix is to let the task decide its own severity:

```ruby
class Users::ApplyReferralBonus < CMDx::Task
  required :user
  required :referral_code, presence: true

  def work
    referrer = User.find_by(referral_code: referral_code)

    if referrer.nil?
      skip!("Invalid referral code — skipping bonus")
      return
    end

    Referral.create!(
      referrer: referrer,
      referred: user,
      bonus_type: :signup,
      status: :pending
    )
    referrer.increment!(:referral_count)
  end
end
```

By using `skip!` instead of `fail!`, the referral step reports the issue in logs and on the result, but the workflow continues. The user gets registered, verified, and welcomed — the referral bonus is just missing.

This is the approach I prefer. The task decides its own severity. Critical steps `fail!`, non-critical steps `skip!`.

## Observability for Free

Configure the JSON log formatter (the default `Line` formatter is human-readable; switch when you want machine-parseable output):

```ruby
CMDx.configure do |config|
  config.log_formatter = CMDx::LogFormatters::JSON.new
end
```

Run the workflow and the message field of each log line is the serialized `result.to_h`:

```json
{"chain_id":"abc123","chain_index":1,"chain_root":false,"type":"Task","task":"Users::Register","status":"success","duration":45.2, ...}
{"chain_id":"abc123","chain_index":2,"chain_root":false,"type":"Task","task":"Users::SendVerification","status":"success","duration":12.1, ...}
{"chain_id":"abc123","chain_index":3,"chain_root":false,"type":"Task","task":"Users::ActivateTrial","status":"success","duration":8.0, ...}
{"chain_id":"abc123","chain_index":4,"chain_root":false,"type":"Task","task":"Users::ApplyReferralBonus","status":"skipped","reason":"Invalid referral code — skipping bonus","duration":3.4, ...}
{"chain_id":"abc123","chain_index":5,"chain_root":false,"type":"Task","task":"Users::SendWelcome","status":"success","duration":6.7, ...}
{"chain_id":"abc123","chain_index":6,"chain_root":false,"type":"Task","task":"Users::TrackRegistration","tags":["analytics","onboarding"],"status":"success","duration":2.1, ...}
{"chain_id":"abc123","chain_index":0,"chain_root":true,"type":"Workflow","task":"Users::Onboard","tags":["onboarding"],"status":"success","duration":76.5, ...}
```

One `chain_id` links every step. The skipped referral bonus is visible without digging through exception trackers. The root workflow result is at `chain_index: 0` (Runtime `unshift`s the root onto the chain). The workflow still reports `success` because skips are considered good outcomes (`result.ok?`).

## Testing the Pipeline

Test each task in isolation, then test the workflow as an integration:

```ruby
RSpec.describe Users::Register do
  it "creates a user with valid inputs" do
    result = Users::Register.execute(
      email: "ada@example.com",
      password: "securepass123",
      plan: "trial"
    )

    expect(result).to be_success
    expect(result.context.user).to be_persisted
    expect(result.context.user.status).to eq("pending_verification")
  end

  it "fails on duplicate email" do
    create(:user, email: "ada@example.com")

    result = Users::Register.execute(
      email: "ada@example.com",
      password: "securepass123",
      plan: "trial"
    )

    expect(result).to be_failed
    expect(result.metadata[:code]).to eq(:duplicate)
  end
end

RSpec.describe Users::Onboard do
  it "runs the full onboarding pipeline" do
    result = Users::Onboard.execute(
      email: "ada@example.com",
      password: "securepass123",
      plan: "trial",
      referral_code: nil
    )

    expect(result).to be_success
    expect(result.context.user).to be_persisted
    expect(result.context.verification_token).to be_present
    expect(result.context.trial_ends_at).to be_present
  end

  it "continues when referral code is invalid" do
    result = Users::Onboard.execute(
      email: "ada@example.com",
      password: "securepass123",
      plan: "free",
      referral_code: "BOGUS"
    )

    expect(result).to be_success
    expect(result.context.user).to be_persisted

    referral_result = result.chain.results.find { |r| r.task == Users::ApplyReferralBonus }
    expect(referral_result).to be_skipped
  end

  it "traces the root cause when registration fails" do
    create(:user, email: "ada@example.com")

    result = Users::Onboard.execute(
      email: "ada@example.com",
      password: "securepass123",
      plan: "trial"
    )

    expect(result).to be_failed
    expect(result.caused_failure.task).to be_a(Users::Register)
    expect(result.caused_failure.metadata[:code]).to eq(:duplicate)
  end
end
```

Unit tests for individual tasks, integration tests for the workflow. The `chain.results` API lets you inspect specific steps within the pipeline.

## The Full Picture

Here's the directory structure for our onboarding feature:

```
app/tasks/
  application_task.rb
  users/
    register.rb
    send_verification.rb
    activate_trial.rb
    apply_referral_bonus.rb
    send_welcome.rb
    track_registration.rb
    onboard.rb
```

Seven files, each under 40 lines. The workflow reads like a checklist. Every step has input validation, output contracts, structured logging, and chain correlation. Add a new onboarding step (say, GDPR consent for EU users) and you write one task, add one line to the workflow with an `if: :eu_user?` conditional, and you're done. Nothing else changes.

That's what real-world CMDx looks like.

Happy coding!

## References

- [Workflows](https://drexed.github.io/cmdx/basics/workflow/)
- [Attributes - Validations](https://drexed.github.io/cmdx/attributes/validations/)
- [Returns](https://drexed.github.io/cmdx/returns/)
- [Halt](https://drexed.github.io/cmdx/interruptions/halt/)
