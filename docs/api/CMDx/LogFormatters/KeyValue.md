# Class: CMDx::LogFormatters::KeyValue
**Inherits:** Object
    

Formats log messages as key-value pairs for structured logging

This formatter converts log entries into key-value format with standardized
fields including severity, timestamp, program name, process ID, and formatted
message. The output is suitable for log parsing tools and human-readable
structured logs.



# Instance Methods
## call(severity, time, progname, message) [](#method-i-call)
Formats a log entry as a key-value string

**@param** [String] The log level (e.g., "INFO", "ERROR", "DEBUG")

**@param** [Time] The timestamp when the log entry was created

**@param** [String, nil] The program name or identifier

**@param** [Object] The log message content

**@return** [String] A key-value formatted log entry with a trailing newline


**@example**
```ruby
logger_formatter.call("INFO", Time.now, "MyApp", "User logged in")
# => "severity=INFO timestamp=2024-01-15T10:30:45.123456Z progname=MyApp pid=12345 message=User logged in\n"
```