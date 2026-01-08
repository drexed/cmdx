# Build powerful, predictable, and maintainable business logic

CMDx is a Ruby framework for clean, composable business logic—designed to replace service-object sprawl.

[Get Started](https://drexed.github.io/cmdx/getting_started/index.md) [View on GitHub](https://github.com/drexed/cmdx)

app/tasks/approve_loan.rb

```ruby
class ApproveLoan < CMDx::Task
  on_success :notify_applicant!

  required :application_id, type: :integer
  optional :override_checks, default: false

  def work
    if application.nil?
      fail!("Application not found", code: 404)
    elsif application.approved?
      skip!("Application already approved")
    else
      context.approval = application.approve!
      context.approved_at = Time.current
    end
  end

  private

  def application
    @application ||= LoanApplication.find_by(id: application_id)
  end

  def notify_applicant!
    ApprovalMailer.approved(application).deliver_later
  end
end
```

## Why Choose CMDx?

Everything you need to build reliable, testable business logic in Ruby

### Zero Dependencies

Pure Ruby with no external dependencies. Works with any Ruby project—Rails, Sinatra, or plain Ruby scripts.

### Type-Safe Attributes

Declare inputs with automatic type coercion, validation, and defaults. Catch errors before they cause problems.

### Built-in Observability

Structured logging with chain IDs, runtime metrics, and execution tracing. Debug complex workflows with ease.

### Composable Workflows

Chain tasks together into sequential pipelines. Build complex processes from simple, tested building blocks.

### Predictable Results

Every execution returns a result object with clear success, failure, or skipped states. No more exception juggling.

### Production Ready

Automatic retries, middleware support, callbacks, and internationalization. Battle-tested in real applications.

## Designed For

CMDx shines wherever you need structured, reliable business logic

### 🏦 Financial Operations

Payment processing, loan approvals, and transaction handling with full audit trails

### 📧 Notification Systems

Multi-channel notifications with fallbacks, personalization, and delivery tracking

### 🔄 Data Pipelines

ETL processes, data migrations, and transformations with checkpoints and recovery

### 🛒 E-commerce Flows

Order processing, inventory management, and fulfillment orchestration

### 👤 User Onboarding

Registration flows, verification steps, and welcome sequences

### 🤖 Background Jobs

Complex async operations with Sidekiq, retry logic, and error handling

## Get Started in Seconds

Add CMDx to your project and start building

```bash
gem install cmdx
# or
bundle add cmdx
```

[Read the Docs](https://drexed.github.io/cmdx/getting_started/index.md) [Star on GitHub](https://github.com/drexed/cmdx)
