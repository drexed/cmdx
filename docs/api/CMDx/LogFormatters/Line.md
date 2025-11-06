# Class: CMDx::LogFormatters::Line
**Inherits:** Object
    

Formats log messages as single-line text for human-readable logging

This formatter converts log entries into a compact single-line format with
severity abbreviation, ISO8601 timestamp, process ID, and formatted message.
The output is optimized for human readability and traditional log file
formats.



# Instance Methods
## call(severity, time, progname, message) [](#method-i-call)
Formats a log entry as a single-line string

**@param** [String] The log level (e.g., "INFO", "ERROR", "DEBUG")

**@param** [Time] The timestamp when the log entry was created

**@param** [String, nil] The program name or identifier

**@param** [Object] The log message content

**@return** [String] A single-line formatted log entry with a trailing newline


**@example**
```ruby
logger_formatter.call("INFO", Time.now, "MyApp", "User logged in")
# => "I, [2024-01-15T10:30:45.123456Z #12345] INFO -- MyApp: User logged in\n"
```