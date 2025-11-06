# Class: CMDx::LogFormatters::Raw
**Inherits:** Object
    

Formats log messages as raw text without additional formatting

This formatter outputs log messages in their original form with minimal
processing, adding only a trailing newline. It's useful for scenarios where
you want to preserve the exact message content without metadata or structured
formatting.



# Instance Methods
## call(severity, time, progname, message) [](#method-i-call)
Formats a log entry as raw text

**@param** [String] The log level (e.g., "INFO", "ERROR", "DEBUG")

**@param** [Time] The timestamp when the log entry was created

**@param** [String, nil] The program name or identifier

**@param** [Object] The log message content

**@return** [String] The raw message with a trailing newline


**@example**
```ruby
logger_formatter.call("INFO", Time.now, "MyApp", "User logged in")
# => "User logged in\n"
```