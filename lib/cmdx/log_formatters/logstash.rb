# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Logstash log formatter for CMDx logging system.
    #
    # Formats log entries as JSON objects compatible with Logstash and the ELK stack
    # (Elasticsearch, Logstash, Kibana). Includes Logstash-specific fields like
    # @version and @timestamp for seamless integration with log aggregation pipelines.
    #
    # @example Basic usage with global logger configuration
    #   CMDx.configure do |config|
    #     config.logger = Logger.new($stdout, formatter: CMDx::LogFormatters::Logstash.new)
    #   end
    #
    # @example Task-specific formatter configuration for ELK stack
    #   class ProcessOrderTask < CMDx::Task
    #     task_settings!(log_format: CMDx::LogFormatters::Logstash.new)
    #
    #     def call
    #       logger.info "Processing order #{order_id}"
    #     end
    #   end
    #
    # @example Sample Logstash JSON output
    #   {"@version":"1","@timestamp":"2022-07-17T18:43:15.000000","severity":"INFO","pid":1234,"index":0,"run_id":"018c2b95-b764-7615","type":"Task","class":"ProcessOrderTask","id":"018c2b95-b764-7615","tags":[],"state":"complete","status":"success","outcome":"success","metadata":{},"runtime":15,"origin":"CMDx"}
    #
    # @example Logstash configuration for CMDx logs
    #   input {
    #     file {
    #       path => "/var/log/cmdx/*.log"
    #       codec => "json"
    #     }
    #   }
    #   filter {
    #     if [origin] == "CMDx" {
    #       # Process CMDx-specific fields
    #     }
    #   }
    #
    # @see CMDx::LogFormatters::Json For standard JSON formatting without Logstash fields
    # @see CMDx::LoggerSerializer For details on serialized data structure
    # @see https://www.elastic.co/guide/en/logstash/current/event-api.html Logstash Event API
    class Logstash

      # Formats a log entry as a Logstash-compatible JSON string.
      #
      # Creates a JSON object with Logstash-specific metadata fields (@version, @timestamp)
      # combined with task execution data, severity, and process information for
      # seamless integration with ELK stack log processing pipelines.
      #
      # @param severity [String] Log severity level (DEBUG, INFO, WARN, ERROR, FATAL)
      # @param time [Time] Timestamp when the log entry was created
      # @param task [CMDx::Task] Task instance being logged
      # @param message [Object] Log message or data to be included
      #
      # @return [String] Single-line Logstash-compatible JSON string with newline terminator
      #
      # @example Success log entry for Logstash
      #   formatter = CMDx::LogFormatters::Logstash.new
      #   output = formatter.call("INFO", Time.now, task, "Order processed")
      #   # => {"@version":"1","@timestamp":"2022-07-17T18:43:15.000000","severity":"INFO",...}\n
      #
      # @example Error log entry with failure chain for ELK analysis
      #   output = formatter.call("ERROR", Time.now, task, error_details)
      #   # => {"@version":"1","severity":"ERROR","caused_failure":{...},"threw_failure":{...},...}\n
      #
      # @note The @version field is always set to "1" following Logstash conventions
      # @note The @timestamp field uses ISO 8601 format for Elasticsearch compatibility
      # @note All CMDx logs include an "origin" field set to "CMDx" for easy filtering
      def call(severity, time, task, message)
        m = LoggerSerializer.call(severity, time, task, message).merge!(
          severity:,
          pid: Process.pid,
          "@version" => "1",
          "@timestamp" => Utils::LogTimestamp.call(time.utc)
        )

        JSON.dump(m) << "\n"
      end

    end
  end
end
