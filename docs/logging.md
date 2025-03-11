# Logging

Tasks log the result object after execution. Multi-threaded systems will have many
tasks executing concurrently so `CMDx` uses a custom logger to make debugging easier.

## Output

Built-in log formatters are: `Line` (default), `Json`, `KeyValue`, `Logstash`, `PrettyLine`, `Raw`

#### Success:
```txt
I, [2022-07-17T18:43:15.000000 #3784] INFO -- CMDx: index=0 run_id=018c2b95-b764-7615-a924-cc5b910ed1e5 type=Task class=SimulationTask id=018c2b95-b764-7615-a924-cc5b910ed1e5 state=complete status=success outcome=success metadata={} runtime=0 tags=[] pid=3784
```

#### Skipped:
```txt
W, [2022-07-17T18:43:15.000000 #3784] WARN -- CMDx: index=0 run_id=018c2b95-b764-7615-a924-cc5b910ed1e5 type=Task class=SimulationTask id=018c2b95-b764-7615-a924-cc5b910ed1e5 state=interrupted status=skipped outcome=skipped metadata={} runtime=0 tags=[] pid=3784
```

#### Failed:
```txt
E, [2022-07-17T18:43:15.000000 #3784] ERROR -- CMDx: index=0 run_id=018c2b95-b764-7615-a924-cc5b910ed1e5 type=Task class=SimulationTask id=018c2b95-b764-7615-a924-cc5b910ed1e5 state=interrupted status=failed outcome=failed metadata={} runtime=0 tags=[] pid=3784
```

#### Level 1 subtask failure:
```txt
E, [2022-07-17T18:43:15.000000 #3784] ERROR -- CMDx: index=0 run_id=018c2b95-b764-7615-a924-cc5b910ed1e5 type=Task class=SimulationTask id=018c2b95-b764-7615-a924-cc5b910ed1e5 state=interrupted status=failed outcome=interrupted metadata={} runtime=0 tags=[] pid=3784 caused_failure={:index=>1, :run_id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :type=>"Task", :class=>"SimulationTask", :id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :state=>"interrupted", :status=>"failed", :outcome=>"failed", :metadata=>{}, :runtime=>0, :tags=>[], :pid=>3784} threw_failure={:index=>1, :run_id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :type=>"Task", :class=>"SimulationTask", :id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :state=>"interrupted", :status=>"failed", :outcome=>"failed", :metadata=>{}, :runtime=>0, :tags=>[], :pid=>3784}
```

#### Level 2+ subtask failure:
```txt
E, [2022-07-17T18:43:15.000000 #3784] ERROR -- CMDx: index=0 run_id=018c2b95-b764-7615-a924-cc5b910ed1e5 type=Task class=SimulationTask id=018c2b95-b764-7615-a924-cc5b910ed1e5 state=interrupted status=failed outcome=interrupted metadata={} runtime=0 tags=[] pid=3784 caused_failure={:index=>2, :run_id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :type=>"Task", :class=>"SimulationTask", :id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :state=>"interrupted", :status=>"failed", :outcome=>"failed", :metadata=>{}, :runtime=>0, :tags=>[], :pid=>3784} threw_failure={:index=>1, :run_id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :type=>"Task", :class=>"SimulationTask", :id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :state=>"interrupted", :status=>"failed", :outcome=>"interrupted", :metadata=>{}, :runtime=>0, :tags=>[], :pid=>3784}
```

## Logger

CMDx defaults to using Ruby's standard library Logger. Log levels thus follow the
[stdlib documentation](http://www.ruby-doc.org/stdlib/libdoc/logger/rdoc/Logger.html).

#### Global settings:

```ruby
CMDx.configure do |config|
  # Single declaration:
  config.logger = Logger.new($stdout, formatter: CMDx::LogFormatters::Line.new, level: Logger::DEBUG)

  # Multiline declarations:
  config.logger           = Rails.logger
  config.logger.formatter = CMDx::LogFormatters::Line.new
  config.logger.level     = Logger::WARN
end
```

#### Task settings:

```ruby
class ProcessOrderTask < CMDx::Task

  task_settings!(logger: Rails.logger, log_format: CMDx::LogFormatters::Logstash.new, log_level: Logger::WARN)

  def call
    # Do work...
  end

end
```

> [!TIP]
> In production environments, a log level of DEBUG may be too verbose for your needs.
> For quieter logs that use less disk space, you can change the log level to only show INFO and higher.

## Write to log

Write to log via the `logger` method.

```ruby
class ProcessOrderTask < CMDx::Task

  def call
    logger.info "Processing order"
    logger.debug { context.to_h }
  end

end
```

## Output format

Define a custom log formatter to match your expected output, for example one that changes the JSON keys:

```ruby
class CustomCmdxLogFormat
  def call(severity, time, progname, message)
    # Return string, hash, array, etc to output...
  end
end
```

---

- **Prev:** [Batch](https://github.com/drexed/cmdx/blob/main/docs/batch.md)
- **Next:** [Tips & Tricks](https://github.com/drexed/cmdx/blob/main/docs/tips_and_tricks.md)
