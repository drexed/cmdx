# Tips and Tricks

This guide covers advanced patterns and optimization techniques for getting the most out of CMDx in production applications.

## Table of Contents

- [Project Organization](#project-organization)
  - [Directory Structure](#directory-structure)
  - [Naming Conventions](#naming-conventions)
  - [Story Telling](#story-telling)
  - [Style Guide](#style-guide)
- [Attribute Options](#attribute-options)
- [ActiveRecord Query Tagging](#activerecord-query-tagging)

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

## ActiveRecord Query Tagging

Automatically tag SQL queries for better debugging:

```ruby
# config/application.rb
config.active_record.query_log_tags_enabled = true
config.active_record.query_log_tags << :cmdx_task_class
config.active_record.query_log_tags << :cmdx_chain_id

# app/tasks/application_task.rb
class ApplicationTask < CMDx::Task
  before_execution :set_execution_context

  private

  def set_execution_context
    # NOTE: This could easily be made into a middleware
    ActiveSupport::ExecutionContext.set(
      cmdx_task_class: self.class.name,
      cmdx_chain_id: chain.id
    )
  end
end

# SQL queries will now include comments like:
# /*cmdx_task_class:ExportReportTask,cmdx_chain_id:018c2b95-b764-7615*/ SELECT * FROM reports WHERE id = 1
```

---

- **Prev:** [Workflows](workflows.md)
- **Next:** [Getting Started](getting_started.md)
