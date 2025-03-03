# Configuration

Configuration of tasks can be done at global and task levels.

## Global settings

Run `rails g cmdx:install` to generate a configuration file within the
`config/initializers` directory. These settings will be preloaded into all tasks.

```ruby
CMDx.configure do |config|
  # Define which statuses a bang `call!` will halt and raise a fault.
  # This option can accept an array of statuses.
  config.task_halt = CMDx::Result::FAILED

  # Enable task timeouts to prevent call execution beyond a defined threshold.
  config.task_timeout = nil

  # Define which statuses a batch task will halt execution from proceeding to the next step.
  # By default skipped tasks are treated as a NOOP so processing is continued.
  # This option can accept an array of statuses.
  config.batch_halt = CMDx::Result::FAILED

  # Enable batch timeouts to prevent call execution beyond a defined threshold.
  # TIP: remember to account for all defined tasks when setting this value
  config.batch_timeout = nil

  # A list of available log formatter can be found at:
  # https://github.com/drexed/cmdx/tree/main/lib/cmdx/log_formatters
  config.logger = Logger.new($stdout, formatter: CMDx::LogFormatters::Line.new)
end
```

## Task settings

Finely tune tasks via class level settings.

```ruby
class ProcessOrderTask < CMDx::Task

  # Task level settings:
  task_settings!(task_timeout: 1, tags: ["v1", "DEPRECATED"])

  def call
    # Do work...
  end

end
```

> [!NOTE]
> `tags` is a task level setting only. Tags will automatically be appended to logs.

---

- **Prev:** [Configuration](https://github.com/drexed/cmdx/blob/main/docs/configuration.md)
- **Next:** [Basics - Setup](https://github.com/drexed/cmdx/blob/main/docs/basics/setup.md)
