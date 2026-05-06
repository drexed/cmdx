# Inputs - Naming

Sometimes the **keyword** your callers use (`:template`) and the **method** you want inside `work` (`context_template`) shouldn’t be the same word. Naming options tweak the reader — **not** what goes in `execute(...)`.

Note

Reach for this when a name would collide with Ruby/CMDx methods, or when `context_foo` reads clearer than plain `foo`.

## Prefix

Stick text **in front** of the accessor.

```ruby
class GenerateReport < CMDx::Task
  input :template, prefix: true              # derives from source name (default :context)
  input :format, prefix: "report_"
  input :owner, source: :account, prefix: true

  def work
    context_template #=> "monthly_sales"
    report_format    #=> "pdf"
    account_owner    #=> account.owner
  end
end

GenerateReport.execute(template: "monthly_sales", format: "pdf")
```

## Suffix

Stick text **after** the accessor.

```ruby
class DeployApplication < CMDx::Task
  input :branch, suffix: true
  input :version, suffix: "_tag"

  def work
    branch_context #=> "main"
    version_tag    #=> "v1.2.3"
  end
end

DeployApplication.execute(branch: "main", version: "v1.2.3")
```

## As

Rename the reader completely — great for reserved words or collisions:

```ruby
class ScheduleMaintenance < CMDx::Task
  input :scheduled_at, as: :scheduled_time

  def work
    scheduled_time #=> #<DateTime>
  end
end

ScheduleMaintenance.execute(scheduled_at: DateTime.new(2024, 12, 15, 2, 0, 0))
```

Important

If you pass `:as` together with `:prefix` / `:suffix`, `:as` wins — affixes are ignored.
