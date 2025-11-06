# Class: CMDx::LogFormatters::Logstash
**Inherits:** Object
    

Formats log messages as Logstash-compatible JSON for structured logging

This formatter converts log entries into Logstash-compatible JSON format with
standardized fields including @version, @timestamp, severity, program name,
process ID, and formatted message. The output follows Logstash event format
specifications for seamless integration with ELK stack and similar systems.



# Instance Methods
## call(severity, time, progname, message) [](#method-i-call)
Formats a log entry as a Logstash-compatible JSON string

**@param** [String] The log level (e.g., "INFO", "ERROR", "DEBUG")

**@param** [Time] The timestamp when the log entry was created

**@param** [String, nil] The program name or identifier

**@param** [Object] The log message content

**@return** [String] A Logstash-compatible JSON-formatted log entry with a trailing newline


**@example**
```ruby
logger_formatter.call("INFO", Time.now, "MyApp", "User logged in")
# => '{"severity":"INFO","progname":"MyApp","pid":12345,"message":"User logged in","@version":"1","@timestamp":"2024-01-15T10:30:45.123456Z"}\n'
```