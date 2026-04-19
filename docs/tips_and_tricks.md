# Tips and Tricks

Patterns and conventions for building maintainable CMDx applications.

## Project Organization

### Directory Structure

A predictable layout keeps tasks discoverable as a project grows:

```text
/app/
└── /tasks/
    ├── /invoices/
    │   ├── calculate_tax.rb
    │   ├── validate_invoice.rb
    │   ├── send_invoice.rb
    │   └── process_invoice.rb # workflow
    ├── /reports/
    │   ├── generate_pdf.rb
    │   ├── compile_data.rb
    │   ├── export_csv.rb
    │   └── create_reports.rb # workflow
    ├── application_task.rb # base class
    ├── authenticate_session.rb
    └── activate_account.rb
```

### Naming Conventions

Follow consistent naming patterns for clarity:

```ruby
# Verb + Noun
class ExportData < CMDx::Task; end
class CompressFile < CMDx::Task; end
class ValidateSchema < CMDx::Task; end

# Use present-tense verbs for actions
class GenerateToken < CMDx::Task; end      # ✓ Good
class GeneratingToken < CMDx::Task; end    # ❌ Avoid
class TokenGeneration < CMDx::Task; end    # ❌ Avoid
```

### Story Telling

Break complex logic into descriptively named methods so `work` reads like a narrative:

```ruby
class ProcessOrder < CMDx::Task
  def work
    charge_payment_method
    assign_to_warehouse
    send_notification
  end

  private

  def charge_payment_method
    order.primary_payment_method.charge!
  end

  def assign_to_warehouse
    order.ready_for_shipping!
  end

  def send_notification
    if order.products_out_of_stock?
      OrderMailer.pending(order).deliver
    else
      OrderMailer.preparing(order).deliver
    end
  end
end
```

### Style Guide

Follow this order for consistent, readable tasks:

```ruby
class ExportReport < CMDx::Task

  # 1. Settings, retries, deprecation
  settings tags: [:reporting]
  retry_on Net::ReadTimeout, limit: 3, jitter: :exponential

  # 2. Register custom extensions
  register :middleware, Telemetry::Middleware.new
  register :validator, :phone, PhoneValidator

  # 3. Define callbacks
  before_execution :find_report
  on_complete :track_export_metrics, if: ->(task) { Current.tenant.analytics? }

  # 4. Declare inputs
  optional :user_id
  required :report_id, coerce: :integer
  optional :format_type, coerce: :string, inclusion: { in: %w[pdf csv] }

  # 5. Declare outputs (the contract)
  output :exported_at, required: true

  # 6. Define work
  def work
    report.compile!
    report.export!

    context.exported_at = Time.now
  end

  # TIP: Favor private business logic to reduce the surface of the public API.
  private

  # 7. Helpers
  def find_report
    @report ||= Report.find(report_id)
  end

  def track_export_metrics
    Analytics.increment(:report_exported)
  end

end
```

## Sharing Input Options

Use `with_options` to factor out repeated options across input declarations.

!!! note

    `with_options` is provided by ActiveSupport and is available automatically in Rails. For plain Ruby projects, add `require "active_support/core_ext/object/with_options"` or apply shared options manually.

```ruby
class ConfigureCompany < CMDx::Task
  with_options(coerce: :string, presence: true) do
    optional :website, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
    required :company_name, :industry
    optional :description, format: { with: /\A[\w\s\-\.,!?]+\z/ }
  end

  required :headquarters do
    with_options(coerce: :string) do
      optional :street, :city, :zip_code
      required :country, inclusion: { in: VALID_COUNTRIES }
      optional :region
    end
  end

  def work
    # ...
  end
end
```

`with_options` works inside nested-input blocks too because the child DSL is evaluated with `instance_eval`.

## Sharing Behavior via a Base Class

Pull cross-cutting concerns onto a base task. Subclasses inherit `settings`, `callbacks`, `middlewares`, `coercions`, `validators`, `telemetry`, and `retry_on` automatically.

```ruby
class ApplicationTask < CMDx::Task
  settings tags: [:app]

  retry_on Net::OpenTimeout, Net::ReadTimeout, limit: 2

  before_execution :ensure_current_tenant!

  private

  def ensure_current_tenant!
    fail!("missing tenant") if Current.tenant.nil?
  end
end

class ProcessInvoice < ApplicationTask
  required :invoice_id, coerce: :integer

  def work
    # Inherits settings, retry_on, and the before_execution callback
  end
end
```

Inherited registries (callbacks, middlewares, validators, coercions) accumulate — declaring more in a subclass appends to the parent's list. To opt out of an inherited entry, use `deregister` (e.g. `deregister :callback, :before_execution, :ensure_current_tenant!`). `retry_on` and `settings` likewise accumulate via merge: a subclass `retry_on` adds exception classes and overrides individual options (`limit:`, `delay:`, …) without dropping the parent's, and `settings` merges new keys on top.

## Useful Examples

- [Active Job Durability](https://github.com/drexed/cmdx/blob/main/examples/active_job_durability.md)
- [Active Record Database Transaction](https://github.com/drexed/cmdx/blob/main/examples/active_record_database_transaction.md)
- [Active Record Query Tagging](https://github.com/drexed/cmdx/blob/main/examples/active_record_query_tagging.md)
- [Active Support Instrumentation](https://github.com/drexed/cmdx/blob/main/examples/active_support_instrumentation.md)
- [Flipper Feature Flags](https://github.com/drexed/cmdx/blob/main/examples/flipper_feature_flags.md)
- [OpenAPI Schema Generation](https://github.com/drexed/cmdx/blob/main/examples/openapi_schema_generation.md)
- [Paper Trail Whatdunnit](https://github.com/drexed/cmdx/blob/main/examples/paper_trail_whatdunnit.md)
- [PubSub Task Chaining](https://github.com/drexed/cmdx/blob/main/examples/pub_sub_task_chaining.md)
- [Redis Idempotency](https://github.com/drexed/cmdx/blob/main/examples/redis_idempotency.md)
- [Sentry Error Tracking](https://github.com/drexed/cmdx/blob/main/examples/sentry_error_tracking.md)
- [Sidekiq Async Execution](https://github.com/drexed/cmdx/blob/main/examples/sidekiq_async_execution.md)
- [Stoplight Circuit Breaker](https://github.com/drexed/cmdx/blob/main/examples/stoplight_circuit_breaker.md)
