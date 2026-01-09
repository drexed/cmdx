---
date: 2026-02-18
authors:
  - drexed
categories:
  - Best Practices
slug: cmdx-tips-and-tricks
---

# CMDx Tips and Tricks: Patterns for Maintainable Applications

We've all been there. You start a new project with the best intentions. The code is clean, the logic is simple, and everything feels manageable. But as the application grows, complexity creeps in. "Just one more service object," we say. "I'll refactor this later," we promise.

Before you know it, you're navigating a maze of inconsistently named files and spaghetti code.

That's why I want to share some of the patterns and techniques I rely on to keep CMDx applications maintainable and scalable. These aren't just theoretical rules; they are practical tips I use every day to keep my Ruby codebases sane.

<!-- more -->

## Organizing Your Project

One of the first questions I often get is, "Where do I put my commands?"

I've found that a thoughtful directory structure is your first line of defense against chaos. Instead of dumping everything into a generic `services` folder, I prefer grouping tasks by domain or resource.

Here is a structure that has served me well:

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
    │   └── create_reports.rb # workflow
    ├── application_task.rb # base class
    └── authenticate_session.rb
```

This structure immediately tells you *what* the application does, not just *how* it's implemented. It groups related functionality, making it easier to find what you're looking for when you need to make a change.

## The Power of Naming

Naming things is hard, right? But in CMDx, consistent naming is crucial for clarity.

I stick to a strict **Verb + Noun** convention for my task classes. It makes the intent of the class instantly obvious.

```ruby
# Verb + Noun
class ExportData < CMDx::Task; end
class CompressFile < CMDx::Task; end
class ValidateSchema < CMDx::Task; end
```

I also make sure to use present tense verbs for actions. It keeps things active and consistent.

```ruby
class GenerateToken < CMDx::Task; end      # ✓ Good
class GeneratingToken < CMDx::Task; end    # ❌ Avoid
class TokenGeneration < CMDx::Task; end    # ❌ Avoid
```

When you see `GenerateToken`, you know exactly what that class is going to do. No ambiguity.

## Telling a Story with Code

The `work` method in your task should read like a narrative. I try to avoid dumping low-level logic directly into `work`. Instead, I break complex logic into descriptive private methods.

Check this out:

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

See how the `work` method tells the story of processing an order? "First, charge the payment. Then, assign to warehouse. Finally, send a notification." It's self-documenting code at its finest.

## A Consistent Style Guide

Consistency within the file is just as important as the file structure itself. I follow a specific order in my task definitions to make them readable.

1.  **Register functions** (middlewares, validators)
2.  **Define callbacks** (before/after execution)
3.  **Declare attributes** (inputs)
4.  **Define the work method** (main logic)
5.  **Build helper functions** (private methods)

Here is a blueprint I use:

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

When every file follows this pattern, you stop hunting for "where are the attributes defined?" and just know where to look.

## DRYing Up Attributes

If you find yourself repeating the same options for multiple attributes, `with_options` is a lifesaver. It works very similarly to the Rails feature you might already know.

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

This keeps your attribute definitions clean and reduces copy-paste errors.

## Wrapping Up

Building maintainable applications isn't about one magic trick; it's about the accumulation of small, consistent habits. By organizing your files, naming things clearly, writing narrative code, and adhering to a style guide, you set yourself (and your team) up for success.

I hope these tips help you write better CMDx tasks. Give them a try in your next project!
