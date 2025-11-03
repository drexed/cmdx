# Attributes - Naming

Customize accessor method names to avoid conflicts and improve clarity. Affixing changes only the generated methods—not the original attribute names.

!!! note

    Use naming when attributes conflict with existing methods or need better clarity in your code.

## Prefix

Adds a prefix to the generated accessor method name.

```ruby
class GenerateReport < CMDx::Task
  # Dynamic from attribute source
  attribute :template, prefix: true

  # Static
  attribute :format, prefix: "report_"

  def work
    context_template #=> "monthly_sales"
    report_format    #=> "pdf"
  end
end

# Attributes passed as original attribute names
GenerateReport.execute(template: "monthly_sales", format: "pdf")
```

## Suffix

Adds a suffix to the generated accessor method name.

```ruby
class DeployApplication < CMDx::Task
  # Dynamic from attribute source
  attribute :branch, suffix: true

  # Static
  attribute :version, suffix: "_tag"

  def work
    branch_context #=> "main"
    version_tag    #=> "v1.2.3"
  end
end

# Attributes passed as original attribute names
DeployApplication.execute(branch: "main", version: "v1.2.3")
```

## As

Completely renames the generated accessor method.

```ruby
class ScheduleMaintenance < CMDx::Task
  attribute :scheduled_at, as: :when

  def work
    when #=> <DateTime>
  end
end

# Attributes passed as original attribute names
ScheduleMaintenance.execute(scheduled_at: DateTime.new(2024, 12, 15, 2, 0, 0))
```
