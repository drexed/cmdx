# Tips & Tricks

## Configuration

Configure `CMDx` to get the most out of your Rails application.

```ruby
CMDx.configure do |config|
  # Redirect your logs through the app defined logger:
  config.logger = Rails.logger

  # Adjust the log level to write depending on the environment:
  config.logger.level = Rails.env.development? ? Logger::DEBUG : Logger::INFO

  # Structure log lines using a pre-built or custom formatter:
  config.logger.formatter = CMDx::LogFormatters::Logstash.new
end
```

## Setup

While not required, a common setup involves creating an `app/cmds` directory
to place all of your tasks and batches under, eg:

```txt
/app
  /cmds
    /notifications
      - deliver_email_task.rb
      - post_slack_message_task.rb
      - send_carrier_pigeon_task.rb
      - batch_deliver_all.rb
    - process_order_task.rb
    - application_batch.rb
    - application_task.rb
```

> [!TIP]
> Prefix batches with `batch_` and suffix tasks with `_task` to they convey their function.
> Use a verb+noun naming structure to convey the work that will be performed, eg:
> `BatchDeliverNotifications` or `DeliverEmailTask`

## Parameters

Use the Rails `with_options` as an elegant way to factor duplication
out of options passed to a series of parameter definitions. The following
are a few common example:

```ruby
class UpdateUserDetailsTask < CMDx::Task

  # Apply `type: :string, presence: true` to this set of parameters:
  with_options(type: :string, presence: true) do
    required :email, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i }
    optional :first_name, :last_name
  end

  required :address do
    # Apply the `address_*` prefix to this set of nested parameters:
    with_options(prefix: :address_) do
      required :city, :country
      optional :state
    end
  end

  def call
    # Do work
  end

end
```

[Learn More](https://api.rubyonrails.org/classes/Object.html#method-i-with_options)
about its usages on the official Rails docs.

## ActiveRecord Query Log Tags

Automatically append comments to SQL queries with runtime information tags.
This can be used to trace troublesome SQL statements back to the application
code that generated these statements.

```ruby
# in config/application.rb
config.active_record.query_log_tags_enabled = true
config.active_record.query_log_tags << :cmdx_task_class


class ApplicationTask

  before_execution :set_execution_context

  # -- omitted --

  private

  def set_execution_context
    ActiveSupport::ExecutionContext.set(cmdx_task_class: self.class.name, &)
  end

end
```

[Learn More](https://api.rubyonrails.org/classes/ActiveRecord/QueryLogs.html)
about its usages on the official Rails docs.

Other examples:
- [https://build.betterup.com/adding-sidekiq-job-context-to-activerecord-query-log-tags/](https://build.betterup.com/adding-sidekiq-job-context-to-activerecord-query-log-tags/)
- [https://thoughtbot.com/blog/activerecord-query-log-tags-for-graphql](https://thoughtbot.com/blog/activerecord-query-log-tags-for-graphql)


---

- **Prev:** [Logging](https://github.com/drexed/cmdx/blob/main/docs/logging.md)
- **Next:** [Example](https://github.com/drexed/cmdx/blob/main/docs/example.md)
