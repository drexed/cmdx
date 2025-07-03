# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Raw log formatter for CMDx logging system.
    #
    # Outputs only the raw message content without any additional formatting,
    # timestamps, severity indicators, or task metadata. Provides the simplest
    # possible log output containing just the inspected message content.
    #
    # @example Basic usage with global logger configuration
    #   CMDx.configure do |config|
    #     config.logger = Logger.new($stdout, formatter: CMDx::LogFormatters::Raw.new)
    #   end
    #
    # @example Task-specific formatter configuration
    #   class ProcessOrderTask < CMDx::Task
    #     task_settings!(log_format: CMDx::LogFormatters::Raw.new)
    #
    #     def call
    #       logger.info "Processing order #{order_id}"
    #       logger.debug({ order_details: order.attributes })
    #     end
    #   end
    #
    # @example Sample raw output
    #   "Processing order 12345"
    #   {:order_details=>{:id=>12345, :status=>"pending"}}
    #
    # @see CMDx::LogFormatters::Line For structured log formatting with metadata
    # @see CMDx::LogFormatters::Json For JSON-formatted output
    class Raw

      # Formats a log entry as raw message content only.
      #
      # Outputs only the message parameter using Ruby's inspect method,
      # ignoring all other log context including severity, timestamp, and task information.
      # Useful for debugging scenarios where only the message content is relevant.
      #
      # @param _severity [String] Log severity level (ignored)
      # @param _time [Time] Timestamp when the log entry was created (ignored)
      # @param _task [CMDx::Task] Task instance being logged (ignored)
      # @param message [Object] Log message or data to be output
      #
      # @return [String] Raw message content with inspect formatting and newline terminator
      #
      # @example String message output
      #   formatter = CMDx::LogFormatters::Raw.new
      #   output = formatter.call("INFO", Time.now, task, "Order processed")
      #   # => "\"Order processed\"\n"
      #
      # @example Hash message output
      #   data = { order_id: 12345, status: "completed" }
      #   output = formatter.call("DEBUG", Time.now, task, data)
      #   # => "{:order_id=>12345, :status=>\"completed\"}\n"
      #
      # @example Array message output
      #   items = ["item1", "item2", "item3"]
      #   output = formatter.call("INFO", Time.now, task, items)
      #   # => "[\"item1\", \"item2\", \"item3\"]\n"
      def call(_severity, _time, _task, message)
        message.inspect << "\n"
      end

    end
  end
end
