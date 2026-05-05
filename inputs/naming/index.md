# Inputs - Naming

Customize accessor method names to avoid conflicts and improve clarity. Affixing changes only the generated reader methods — not the original input names used by callers.

Note

Use naming when inputs conflict with existing methods or need better clarity in your code.

## Prefix

Adds a prefix to the generated accessor method name.

```ruby
class GenerateReport < CMDx::Task
  # Dynamic from input source (defaults to :context)
  input :template, prefix: true

  # Static
  input :format, prefix: "report_"

  # Combined with a custom :source — prefix derives from the source name
  input :owner, source: :account, prefix: true

  def work
    context_template #=> "monthly_sales"
    report_format    #=> "pdf"
    account_owner    #=> account.owner
  end
end

# Inputs passed under their original names
GenerateReport.execute(template: "monthly_sales", format: "pdf")
```

## Suffix

Adds a suffix to the generated accessor method name.

```ruby
class DeployApplication < CMDx::Task
  # Dynamic from input source (defaults to :context)
  input :branch, suffix: true

  # Static
  input :version, suffix: "_tag"

  def work
    branch_context #=> "main"
    version_tag    #=> "v1.2.3"
  end
end

# Inputs passed under their original names
DeployApplication.execute(branch: "main", version: "v1.2.3")
```

## As

Completely renames the generated accessor method. Useful when the natural input name collides with a reserved word or an existing method:

```ruby
class ScheduleMaintenance < CMDx::Task
  input :scheduled_at, as: :scheduled_time

  def work
    scheduled_time #=> #<DateTime>
  end
end

# Input still passed under its original name
ScheduleMaintenance.execute(scheduled_at: DateTime.new(2024, 12, 15, 2, 0, 0))
```

Important

`:as` overrides `:prefix` and `:suffix` — when all three are given, `:as` wins and the affixes are ignored.
