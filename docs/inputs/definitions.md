# Inputs - Definitions

Inputs are your task’s **public contract**: “Here’s what you can pass in, and here’s how we’ll clean it up.” Each line builds a reader method and wires coercion, validation, defaults, transforms, and conditional `:if` / `:unless` gates.

## Declarations

!!! warning "Order matters"

    Inputs are resolved **top to bottom**. If input B reads from input A (as a `source:` or inside a gate), define **A first**.

```ruby
# Good: credentials exists before connection_string looks at it
required :credentials, source: :database_config
input :connection_string, source: :credentials

# Bad: connection_string runs before credentials exists
input :connection_string, source: :credentials
required :credentials, source: :database_config
```

!!! warning "Name clashes"

    If an input name would stomp on a Ruby or CMDx method, class loading blows up with `CMDx::DefinitionError`. Rename with `:as`, `:prefix`, or `:suffix` — see [Naming](naming.md).

!!! tip

    `required` and `optional` read nicer than `inputs(..., required: …)` — they broadcast intent in one word.

### Optional

Caller doesn’t have to pass these. If they skip one, you see `nil` (unless you add a `default:` elsewhere).

```ruby
class ScheduleEvent < CMDx::Task
  input :title
  inputs :duration, :location

  # Same as inputs ..., required: false — usually nicer to read
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

ScheduleEvent.execute(
  title: "Team Standup",
  duration: 30,
  attendees: ["alice@company.com", "bob@company.com"]
)
```

### Required

These **must** show up in the keyword args (or whatever you’re executing with), or the task fails fast.

```ruby
class PublishArticle < CMDx::Task
  input :title, required: true
  inputs :content, :author_id, required: true

  required :category
  required :status, :tags

  # Sometimes required only in certain situations
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

!!! note

    A “required” input behind a falsy `:if` / `:unless` behaves like optional for that run. Coercion, validation, defaults, and transforms still apply when it **does** run.

## Removals

Subclass inherited inputs you don’t want? `deregister` strips them (and nested children). Always use the **original** declaration name — not the accessor after `:as` / `:prefix` / `:suffix`:

```ruby
class ApplicationTask < CMDx::Task
  required :tenant_id
  optional :debug_mode
  required :user_id, as: :customer_id   # reader is customer_id
end

class PublicTask < ApplicationTask
  deregister :input, :tenant_id
  deregister :input, :debug_mode
  deregister :input, :user_id           # still :user_id, not :customer_id

  def work
    # tenant_id, debug_mode, and customer_id are gone
  end
end
```

!!! warning

    `deregister :input, *names` removes real inputs only. Typos raise `NoMethodError`.

## Introspection

Want to generate docs or debug? `inputs_schema` hands back everything CMDx knows:

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

Each key includes `:name` (accessor after renaming), `:description`, `:required`, raw `:options`, and nested `:children`.

!!! note

    `:required` in the schema is the **static** flag. Dynamic `:if` / `:unless` isn’t evaluated here — read `options[:if]` / `options[:unless]` yourself if you document conditionals.

!!! note

    Coercion or validation failure leaves the backing ivar `nil`, records errors under the accessor name, skips nested children, and fails the run **before** `work`.

## Sources

By default values come from **context**. `source:` lets you read from a method, proc, callable class, or another input you already declared.

### Context

The everyday path: fields mirror `context`:

```ruby
class BackupDatabase < CMDx::Task
  required :database_name
  optional :compression_level

  input :backup_path, source: :context   # explicit, same default behavior

  def work
    database_name     #=> context.database_name
    backup_path       #=> context.backup_path
    compression_level #=> context.compression_level
  end
end
```

### Symbol references

Point at an instance method — nice when the value needs a little lookup:

```ruby
class BackupDatabase < CMDx::Task
  inputs :host, :credentials, source: :database_config

  input :connection_string, source: :credentials

  def work
    # ...
  end

  private

  def database_config
    @database_config ||= DatabaseConfig.find(context.database_name)
  end
end
```

### Proc or Lambda

Inline “go get this” logic:

```ruby
class BackupDatabase < CMDx::Task
  input :timestamp, source: proc { Time.current }
  input :server, source: -> { Current.server }
end
```

### Class or Module

Heavy lifting in a dedicated object:

```ruby
class DatabaseResolver
  def self.call(task)
    Database.find(task.context.database_name)
  end
end

class BackupDatabase < CMDx::Task
  input :schema, source: DatabaseResolver
  input :metadata, source: DatabaseResolver.new
end
```

## Description

Pure metadata for humans and tools — doesn’t change behavior:

```ruby
class CreateUser < CMDx::Task
  required :email, description: "The user's primary email address"

  optional :phone, desc: "Primary contact number"   # alias :desc

  inputs :first_name, :last_name, desc: "Part of user's legal name"
end
```

## Nesting

Got a hash-shaped blob? Nest inputs under a parent. Kids read from the parent value (`#[]`, `#key?`, or methods). They support the usual options **except** `source:` — nested fields always come from the parent.

!!! note

    Nested inputs get the full toolkit: renaming, coercion, validation, defaults, and more.

```ruby
class ConfigureServer < CMDx::Task
  required :network_config do
    required :hostname, :port, :protocol, :subnet
    optional :load_balancer
    input :firewall_rules
  end

  optional :ssl_config do
    required :certificate_path, :private_key
    optional :enable_http2, prefix: true
  end

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

!!! warning

    Rules inside an optional parent only fire **when that parent is actually provided**. That’s usually what you want.

## Error handling

Problems (missing required fields, bad coercion, failed validation) collect on `task.errors`. When resolution finishes with any errors, the run fails: `result.reason` is a sentence; `result.errors` has the structured map.

!!! note

    Nested children resolve only when the parent exists and isn’t `nil`.

```ruby
class ConfigureServer < CMDx::Task
  required :server_id, :environment
  required :network_config do
    required :hostname, :port
  end

  def work
    # ...
  end
end

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

result = ConfigureServer.execute(
  server_id: "srv-001",
  environment: "production",
  network_config: { hostname: "api.company.com" }
)

result.state       #=> "interrupted"
result.status      #=> "failed"
result.reason      #=> "port is required"
result.errors.to_h #=> { port: ["is required"] }
```
