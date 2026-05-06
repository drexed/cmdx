# Tips and tricks

Welcome to the "make CMDx feel good in a real app" page. None of this is required — it is the stuff that keeps teams smiling when the codebase grows.

## Project organization

### Directory structure

Give tasks a home that matches how you think about the product. When someone opens `app/tasks`, they should nod instead of squint.

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

### Naming conventions

Name tasks like actions: verb + noun, present tense. Your future self reads class names more than comments.

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

### Story telling

Let `work` read like a short story: small private methods with honest names. If you can read it aloud and it makes sense, you have won.

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

### Style guide

Stack declarations in the same order every time — your eyes learn the rhythm. Rough recipe below; tweak if your team agrees on something else, but stay consistent.

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
  on_complete :track_export_metrics, if: -> { Current.tenant.analytics? }

  # 4. Declare inputs
  optional :user_id
  required :report_id, coerce: :integer
  optional :format_type, coerce: :string, inclusion: { in: %w[pdf csv] }

  # 5. Declare outputs (the contract)
  output :exported_at

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

## Sharing input options

Tired of repeating `coerce:` and `presence:` on every line? `with_options` is your DRY friend — one block, many fields.

Note

`with_options` comes from ActiveSupport, so Rails apps get it for free. Plain Ruby? Add `require "active_support/core_ext/object/with_options"` or duplicate the options by hand — both are fine.

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

Nested input blocks work too — the inner DSL runs with `instance_eval`, so `with_options` nest cleanly.

## Sharing behavior via a base class

Got cross-cutting stuff every task needs? Put it on `ApplicationTask` (or whatever you call it) and inherit. Subclasses pick up settings, retries, callbacks, middleware, validators, coercions, executors, mergers, retriers, deprecators, telemetry, inputs, and outputs — the whole toolkit.

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

**How stacking works (without the scary words):** lists generally **grow** as you go down the inheritance chain — new entries append (or replace by name where that applies). `retry_on` and `settings` **merge**: the child adds or overrides keys without throwing away the parent. Need to drop something from mom or dad? `deregister` is the escape hatch — for example `deregister :callback, :before_execution, :ensure_current_tenant!`.

## Useful examples

Real-world recipes live in the repo — grab the one closest to what you are building:

- [Active Job Durability](https://github.com/drexed/cmdx/blob/main/examples/active_job_durability.md)
- [Active Record Database Transaction](https://github.com/drexed/cmdx/blob/main/examples/active_record_database_transaction.md)
- [Active Record Query Tagging](https://github.com/drexed/cmdx/blob/main/examples/active_record_query_tagging.md)
- [Active Support Instrumentation](https://github.com/drexed/cmdx/blob/main/examples/active_support_instrumentation.md)
- [dry-monads Interop](https://github.com/drexed/cmdx/blob/main/examples/dry_monads_interop.md)
- [Flipper Feature Flags](https://github.com/drexed/cmdx/blob/main/examples/flipper_feature_flags.md)
- [GraphQL Resolvers](https://github.com/drexed/cmdx/blob/main/examples/graphql_resolvers.md)
- [OpenAPI Schema Generation](https://github.com/drexed/cmdx/blob/main/examples/openapi_schema_generation.md)
- [OpenTelemetry Tracing](https://github.com/drexed/cmdx/blob/main/examples/opentelemetry_tracing.md)
- [Paper Trail Whatdunnit](https://github.com/drexed/cmdx/blob/main/examples/paper_trail_whatdunnit.md)
- [PubSub Task Chaining](https://github.com/drexed/cmdx/blob/main/examples/pub_sub_task_chaining.md)
- [Pundit Authorization](https://github.com/drexed/cmdx/blob/main/examples/pundit_authorization.md)
- [Rate Limit](https://github.com/drexed/cmdx/blob/main/examples/rate_limit.md)
- [Redis Idempotency](https://github.com/drexed/cmdx/blob/main/examples/redis_idempotency.md)
- [Sentry Error Tracking](https://github.com/drexed/cmdx/blob/main/examples/sentry_error_tracking.md)
- [Sidekiq Async Execution](https://github.com/drexed/cmdx/blob/main/examples/sidekiq_async_execution.md)
- [Stoplight Circuit Breaker](https://github.com/drexed/cmdx/blob/main/examples/stoplight_circuit_breaker.md)
- [Timeout Guard](https://github.com/drexed/cmdx/blob/main/examples/timeout_guard.md)
