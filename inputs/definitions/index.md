# Inputs - Definitions

Inputs declare the task's interface. Each declaration generates an accessor and wires up coercion, validation, defaults, transforms, and `:if`/`:unless` gates.

## Declarations

Important

Inputs are order-dependent. If one input references another as a source or condition, the referenced input must be defined first.

```ruby
# Correct: credentials defined before connection_string
required :credentials, source: :database_config
input :connection_string, source: :credentials

# Wrong: connection_string references credentials before it exists
input :connection_string, source: :credentials
required :credentials, source: :database_config
```

Important

Input names that conflict with existing Ruby or CMDx methods raise `CMDx::DefinitionError` at class-load time. Use `:as`, `:prefix`, or `:suffix` to resolve naming conflicts. See [Naming](https://drexed.github.io/cmdx/inputs/naming/index.md).

Tip

Prefer the `required` and `optional` shorthands over `inputs(..., required: …)` — they read better and make intent obvious at a glance.

### Optional

Optional inputs return `nil` when not provided.

```ruby
class ScheduleEvent < CMDx::Task
  input :title
  inputs :duration, :location

  # Shorthand for inputs ..., required: false (preferred)
  optional :description
  optional :visibility, :attendees

  def work
    title       #=> "Team Standup"
    duration    #=> 30
    location    #=> nil
    description #=> nil
    visibility  #=> nil
    attendees   #=> ["alice@company.com", "bob@company.com"]
  end
end

# Inputs passed as keyword arguments
ScheduleEvent.execute(
  title: "Team Standup",
  duration: 30,
  attendees: ["alice@company.com", "bob@company.com"]
)
```

### Required

Required inputs must be provided in call arguments or task execution will fail.

```ruby
class PublishArticle < CMDx::Task
  input :title, required: true
  inputs :content, :author_id, required: true

  # Shorthand for inputs ..., required: true (preferred)
  required :category
  required :status, :tags

  # Conditionally required
  required :publisher, if: :magazine?
  input :approver, required: true, unless: proc { status == :published }

  def work
    title     #=> "Getting Started with Ruby"
    content   #=> "This is a comprehensive guide..."
    author_id #=> 42
    category  #=> "programming"
    status    #=> :published
    tags      #=> ["ruby", "beginner"]
    publisher #=> "Eastbay"
    approver  #=> #<Editor ...>
  end

  private

  def magazine?
    context.title.end_with?("[M]")
  end
end
```

Note

A required input with a falsy `:if`/`:unless` gate behaves as optional. Coercions, validations, defaults, and transformations still apply.

## Removals

Remove inherited or previously defined inputs and their accessor methods via `deregister`. The lookup key is always the **original input name** — `:as`, `:prefix`, and `:suffix` only affect the generated accessor, not the registry key:

```ruby
class ApplicationTask < CMDx::Task
  required :tenant_id
  optional :debug_mode
  required :user_id, as: :customer_id   # accessor: customer_id
end

class PublicTask < ApplicationTask
  deregister :input, :tenant_id
  deregister :input, :debug_mode
  deregister :input, :user_id           # deregister by original name, NOT :customer_id

  def work
    # tenant_id, debug_mode, and user_id (customer_id) are no longer defined
  end
end
```

Important

`deregister :input, *names` removes inputs (and any nested children). Unknown names raise `NoMethodError`.

## Introspection

Inspect the full input schema for tooling, documentation generation, or debugging:

```ruby
class CreateUser < CMDx::Task
  required :email, coerce: :string, format: /\A.+@.+\z/
  optional :role, default: "member", inclusion: { in: %w[member admin] }
end

CreateUser.inputs_schema
#=> {
#     email: { name: :email, description: nil, required: true,
#              options: { required: true, coerce: :string, format: /\A.+@.+\z/ },
#              children: [] },
#     role:  { name: :role, ... }
#   }
```

Each entry exposes `:name` (the accessor name, post-`:as`/`:prefix`/`:suffix`), `:description`, `:required`, the raw declaration `:options`, and any nested `:children` recursively.

Note

`:required` in the schema is the static flag — `:if` / `:unless` gates aren't evaluated at schema time. Inspect `options[:if]` / `options[:unless]` directly when generating docs.

Note

Failed coercion/validation leaves the backing ivar at `nil`, records the message on `task.errors` under the accessor name, skips nested children, and throws a failed signal before `work` runs.

## Sources

Inputs read from any accessible object — not just context. The default source is `:context`; override with `source:` to pull data from a method, proc, callable class, or another already-defined input:

### Context

```ruby
class BackupDatabase < CMDx::Task
  # Default source is :context
  required :database_name
  optional :compression_level

  # Explicitly specify context source
  input :backup_path, source: :context

  def work
    database_name     #=> context.database_name
    backup_path       #=> context.backup_path
    compression_level #=> context.compression_level
  end
end
```

### Symbol References

Reference instance methods by symbol for dynamic source values:

```ruby
class BackupDatabase < CMDx::Task
  inputs :host, :credentials, source: :database_config

  # Access from declared inputs
  input :connection_string, source: :credentials

  def work
    # Your logic here...
  end

  private

  def database_config
    @database_config ||= DatabaseConfig.find(context.database_name)
  end
end
```

### Proc or Lambda

Use anonymous functions for dynamic source values:

```ruby
class BackupDatabase < CMDx::Task
  # Proc
  input :timestamp, source: proc { Time.current }

  # Lambda
  input :server, source: -> { Current.server }
end
```

### Class or Module

For complex source logic, use classes or modules:

```ruby
class DatabaseResolver
  def self.call(task)
    Database.find(task.context.database_name)
  end
end

class BackupDatabase < CMDx::Task
  # Class or Module
  input :schema, source: DatabaseResolver

  # Instance
  input :metadata, source: DatabaseResolver.new
end
```

## Description

Add metadata to inputs for documentation or introspection purposes.

```ruby
class CreateUser < CMDx::Task
  required :email, description: "The user's primary email address"

  # Alias :desc
  optional :phone, desc: "Primary contact number"

  # Bulk definition - description applies to all
  inputs :first_name, :last_name, desc: "Part of user's legal name"
end
```

## Nesting

Build complex structures with nested inputs. Children resolve from the parent's value (via `respond_to?`, `#[]`, or `#key?`) and support all input options except `:source` — nested children always read from the parent and ignore any `:source` on their own declaration.

Note

Nested inputs support all features: naming, coercions, validations, defaults, and more.

```ruby
class ConfigureServer < CMDx::Task
  # Required parent with required children
  required :network_config do
    required :hostname, :port, :protocol, :subnet
    optional :load_balancer
    input :firewall_rules
  end

  # Optional parent with conditional children
  optional :ssl_config do
    required :certificate_path, :private_key # Only required if ssl_config provided
    optional :enable_http2, prefix: true
  end

  # Multi-level nesting
  input :monitoring do
    required :provider

    optional :alerting do
      required :threshold_percentage
      optional :notification_channel
    end
  end

  def work
    network_config   #=> { hostname: "api.company.com" ... }
    hostname         #=> "api.company.com"
    load_balancer    #=> nil
  end
end

ConfigureServer.execute(
  server_id: "srv-001",
  network_config: {
    hostname: "api.company.com",
    port: 443,
    protocol: "https",
    subnet: "10.0.1.0/24",
    firewall_rules: "allow_web_traffic"
  },
  monitoring: {
    provider: "datadog",
    alerting: {
      threshold_percentage: 85.0,
      notification_channel: "slack"
    }
  }
)
```

Important

Child requirements only apply when the parent is provided, which is what you want for optional structures.

## Error Handling

Resolution failures (missing required inputs, coercion failures, validator failures) accumulate on `task.errors`. When resolution finishes and errors exist, Runtime throws a failed signal: the joined sentence becomes `result.reason`; the structured map is exposed on `result.errors`.

Note

Nested inputs are only resolved when their parent is present and non-`nil`.

```ruby
class ConfigureServer < CMDx::Task
  required :server_id, :environment
  required :network_config do
    required :hostname, :port
  end

  def work
    # Your logic here...
  end
end

# Missing required top-level inputs
result = ConfigureServer.execute(server_id: "srv-001")

result.state              #=> "interrupted"
result.status             #=> "failed"
result.reason             #=> "environment is required. network_config is required"
result.metadata           #=> {}
result.errors.to_h        #=> {
                          #     environment:    ["is required"],
                          #     network_config: ["is required"]
                          #   }
result.errors.full_messages
#=> {
#     environment:    ["environment is required"],
#     network_config: ["network_config is required"]
#   }

# Missing required nested inputs
result = ConfigureServer.execute(
  server_id: "srv-001",
  environment: "production",
  network_config: { hostname: "api.company.com" } # Missing port
)

result.state       #=> "interrupted"
result.status      #=> "failed"
result.reason      #=> "port is required"
result.errors.to_h #=> { port: ["is required"] }
```
