# Attributes - Definitions

Attributes define the interface between task callers and implementation, enabling automatic validation, type coercion, and method generation. They provide a contract to verify that task execution arguments match expected requirements and structure.

## Table of Contents

- [Declarations](#declarations)
  - [Optional](#optional)
  - [Required](#required)
- [Sources](#sources)
  - [Context](#context)
  - [Symbol References](#symbol-references)
  - [Proc or Lambda](#proc-or-lambda)
  - [Class or Module](#class-or-module)
- [Nesting](#nesting)
- [Error Handling](#error-handling)

## Declarations

> [!TIP]
> Prefer using the `required` and `optional` alias for `attributes` for brevity and to clearly signal intent.

### Optional

Optional attributes return `nil` when not provided.

```ruby
class ScheduleEvent < CMDx::Task
  attribute :title
  attributes :duration, :location

  # Alias for attributes (preferred)
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

# Attributes passed as keyword arguments
ScheduleEvent.execute(
  title: "Team Standup",
  duration: 30,
  attendees: ["alice@company.com", "bob@company.com"]
)
```

### Required

Required attributes must be provided in call arguments or task execution will fail.

```ruby
class PublishArticle < CMDx::Task
  attribute :title, required: true
  attributes :content, :author_id, required: true

  # Alias for attributes => required: true (preferred)
  required :category
  required :status, :tags

  def work
    title     #=> "Getting Started with Ruby"
    content   #=> "This is a comprehensive guide..."
    author_id #=> 42
    category  #=> "programming"
    status    #=> :published
    tags      #=> ["ruby", "beginner"]
  end
end

# Attributes passed as keyword arguments
PublishArticle.execute(
  title: "Getting Started with Ruby",
  content: "This is a comprehensive guide...",
  author_id: 42,
  category: "programming",
  status: :published,
  tags: ["ruby", "beginner"]
)
```

## Sources

Attributes delegate to accessible objects within the task. The default source is `:context`, but any accessible method or object can serve as an attribute source.

### Context

```ruby
class BackupDatabase < CMDx::Task
  # Default source is :context
  required :database_name
  optional :compression_level

  # Explicitly specify context source
  attribute :backup_path, source: :context

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
  attributes :host, :credentials, source: :database_config

  # Access from declared attributes
  attribute :connection_string, source: :credentials

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
  attribute :timestamp, source: proc { Time.current }

  # Lambda
  attribute :server, source: -> { Current.server }
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
  attribute :schema, source: DatabaseResolver

  # Instance
  attribute :metadata, source: DatabaseResolver.new
end
```

## Nesting

Nested attributes enable complex attribute structures where child attributes automatically inherit their parent as the source. This allows validation and access of structured data.

> [!NOTE]
> All options available to top-level attributes are available to nested attributes, eg: naming, coercions, and validations

```ruby
class ConfigureServer < CMDx::Task
  # Required parent with required children
  required :network_config do
    required :hostname, :port, :protocol, :subnet
    optional :load_balancer
    attribute :firewall_rules
  end

  # Optional parent with conditional children
  optional :ssl_config do
    required :certificate_path, :private_key # Only required if ssl_config provided
    optional :enable_http2, prefix: true
  end

  # Multi-level nesting
  attribute :monitoring do
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

> [!IMPORTANT]
> Child attributes are only required when their parent attribute is provided, enabling flexible optional structures.

## Error Handling

Attribute validation failures result in structured error information with details about each failed attribute.

> [!NOTE]
> Nested attributes are only ever evaluated when the parent attribute is available and valid.

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

# Missing required top-level attributes
result = ConfigureServer.execute(server_id: "srv-001")

result.state    #=> "interrupted"
result.status   #=> "failed"
result.reason   #=> "environment is required. network_config is required."
result.metadata #=> {
                #     messages: {
                #       environment: ["is required"],
                #       network_config: ["is required"]
                #     }
                #   }

# Missing required nested attributes
result = ConfigureServer.execute(
  server_id: "srv-001",
  environment: "production",
  network_config: { hostname: "api.company.com" } # Missing port
)

result.state    #=> "interrupted"
result.status   #=> "failed"
result.reason   #=> "port is required."
result.metadata #=> {
                #     messages: {
                #       port: ["is required"]
                #     }
                #   }
```

---

- **Prev:** [Outcomes - States](../outcomes/states.md)
- **Next:** [Attributes - Naming](naming.md)
