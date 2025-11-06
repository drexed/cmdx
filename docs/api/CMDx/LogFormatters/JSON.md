# Class: CMDx::LogFormatters::JSON
**Inherits:** Object
    

Formats log messages as JSON for structured logging

This formatter converts log entries into JSON format with standardized fields
including severity, timestamp, program name, process ID, and formatted
message. The output is suitable for log aggregation systems and structured
analysis.



# Instance Methods
## call(severity, time, progname, message) [](#method-i-call)
Formats a log entry as a JSON string

**@param** [String] The log level (e.g., "INFO", "ERROR", "DEBUG")

**@param** [Time] The timestamp when the log entry was created

**@param** [String, nil] The program name or identifier

**@param** [Object] The log message content

**@return** [String] A JSON-formatted log entry with a trailing newline


**@example**
```ruby
logger_formatter.call("INFO", Time.now, "MyApp", "User logged in")
# => '{"severity":"INFO","timestamp":"2024-01-15T10:30:45.123456Z","progname":"MyApp","pid":12345,"message":"User logged in"}\n'
```