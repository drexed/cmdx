# Tips and Tricks

This guide covers advanced patterns and optimization techniques for getting the most out of CMDx in production applications.

## Project Organization

### Directory Structure

Create a well-organized command structure for maintainable applications:

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

Follow consistent naming patterns for clarity and maintainability:

```ruby
# Verb + Noun
class ExportData < CMDx::Task; end
class CompressFile < CMDx::Task; end
class ValidateSchema < CMDx::Task; end

# Use present tense verbs for actions
class GenerateToken < CMDx::Task; end      # ✓ Good
class GeneratingToken < CMDx::Task; end    # ❌ Avoid
class TokenGeneration < CMDx::Task; end    # ❌ Avoid
```

### Story Telling

Consider using descriptive methods to express the task’s flow, rather than concentrating all logic inside the `work` method.

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

Follow a style pattern for consistent task design:

```ruby
class ExportReport < CMDx::Task

  # 1. Register functions
  register :middleware, CMDx::Middlewares::Correlate
  register :validator, :format, FormatValidator

  # 2. Define callbacks
  before_execution :find_report
  on_complete :track_export_metrics, if: ->(task) { Current.tenant.analytics? }

  # 3. Declare attributes
  attributes :user_id
  required :report_id
  optional :format_type

  # 4. Define work method
  def work
    report.compile!
    report.export!

    context.exported_at = Time.now
  end

  # TIP: Favor private business logic to reduce the surface of the public API.
  private

  # 5. Build helper functions
  def find_report
    @report ||= Report.find(report_id)
  end

  def track_export_metrics
    Analytics.increment(:report_exported)
  end

end
```

## Attribute Options

Use Rails `with_options` to reduce duplication and improve readability:

```ruby
class ConfigureCompany < CMDx::Task
  # Apply common options to multiple attributes
  with_options(type: :string, presence: true) do
    attributes :website, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
    required :company_name, :industry
    optional :description, format: { with: /\A[\w\s\-\.,!?]+\z/ }
  end

  # Nested attributes with shared prefix
  required :headquarters do
    with_options(prefix: :hq_) do
      attributes :street, :city, :zip_code, type: :string
      required :country, type: :string, inclusion: { in: VALID_COUNTRIES }
      optional :region, type: :string
    end
  end

  def work
    # Your logic here...
  end
end
```

## Advance Examples

- [Active Record Query Tagging](../examples/active_record_query_tagging.md)
- [Paper Trail Whatdunnit](https://github.com/drexed/cmdx/blob/main/examples/paper_trail_whatdunnit.md)

---

- **Prev:** [Workflows](workflows.md)
- **Next:** [Getting Started](getting_started.md)
