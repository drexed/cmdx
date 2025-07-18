# frozen_string_literal: true

module CMDx
  # Logger serialization module for converting messages and task data into structured log format.
  #
  # LoggerSerializer provides functionality to serialize task execution messages into a
  # standardized hash representation suitable for logging systems. It handles both result
  # objects and arbitrary messages, applying consistent formatting with optional ANSI
  # colorization for terminal output. The serializer intelligently processes different
  # message types and enriches log data with task metadata and origin information.
  module LoggerSerializer

    COLORED_KEYS = %i[
      state status outcome
    ].freeze

    module_function

    # Serializes a log message with task context into structured hash format.
    #
    # Converts log messages into a standardized hash representation suitable for
    # various logging systems and output formats. When the message is a Result object,
    # it extracts the result's hash representation and optionally applies ANSI colors
    # to specific keys for enhanced terminal visibility. For non-result messages,
    # it enriches the log entry with task metadata from TaskSerializer. All log
    # entries are tagged with CMDx origin for source identification.
    #
    # @param severity [Symbol] the log severity level (not used in current implementation)
    # @param time [Time] the timestamp of the log entry (not used in current implementation)
    # @param task [CMDx::Task, CMDx::Workflow] the task or workflow instance providing context
    # @param message [CMDx::Result, Object] the primary message content to serialize
    # @param options [Hash] additional options for serialization behavior
    # @option options [Boolean] :ansi_colorize whether to apply ANSI colors to result keys
    #
    # @return [Hash] a structured hash containing the serialized log message and metadata
    # @option return [String] :origin always set to "CMDx" for source identification
    # @option return [Integer] :index the task's position index in the execution chain (when message is not Result)
    # @option return [String] :chain_id the unique identifier of the task's execution chain (when message is not Result)
    # @option return [String] :type the task type, either "Task" or "Workflow" (when message is not Result)
    # @option return [String] :class the full class name of the task (when message is not Result)
    # @option return [String] :id the unique identifier of the task instance (when message is not Result)
    # @option return [Array] :tags the tags associated with the task from cmd settings (when message is not Result)
    # @option return [Object] :message the original message content (when message is not Result)
    # @option return [Symbol] :state the execution state with optional ANSI colors (when message is Result)
    # @option return [Symbol] :status the execution status with optional ANSI colors (when message is Result)
    # @option return [Symbol] :outcome the execution outcome with optional ANSI colors (when message is Result)
    # @option return [Hash] :metadata additional metadata from result (when message is Result)
    # @option return [Float] :runtime execution runtime in seconds (when message is Result)
    #
    # @raise [NoMethodError] if task doesn't respond to required methods for TaskSerializer
    # @raise [NoMethodError] if result message doesn't respond to to_h method
    #
    # @example Serialize a result message with ANSI colors
    #   task = ProcessDataTask.call(data: "test")
    #   LoggerSerializer.call(:info, Time.now, task, task.result, ansi_colorize: true)
    #   # => {
    #   #   origin: "CMDx",
    #   #   index: 0,
    #   #   chain_id: "abc123",
    #   #   type: "Task",
    #   #   class: "ProcessDataTask",
    #   #   id: "def456",
    #   #   tags: [],
    #   #   state: "\e[0;32;49mcomplete\e[0m",
    #   #   status: "\e[0;32;49msuccess\e[0m",
    #   #   outcome: "\e[0;32;49mgood\e[0m",
    #   #   metadata: {},
    #   #   runtime: 0.045
    #   # }
    #
    # @example Serialize a string message with task context
    #   task = MyTask.new(context: {data: "test"})
    #   LoggerSerializer.call(:warn, Time.now, task, "Processing started")
    #   # => {
    #   #   origin: "CMDx",
    #   #   index: 0,
    #   #   chain_id: "abc123",
    #   #   type: "Task",
    #   #   class: "MyTask",
    #   #   id: "def456",
    #   #   tags: [],
    #   #   message: "Processing started"
    #   # }
    #
    # @example Serialize a result message without colors
    #   task = ValidationTask.call(email: "invalid")
    #   LoggerSerializer.call(:error, Time.now, task, task.result)
    #   # => {
    #   #   origin: "CMDx",
    #   #   index: 1,
    #   #   chain_id: "xyz789",
    #   #   type: "Task",
    #   #   class: "ValidationTask",
    #   #   id: "ghi012",
    #   #   tags: [],
    #   #   state: :interrupted,
    #   #   status: :failed,
    #   #   outcome: :bad,
    #   #   metadata: { reason: "Invalid email format" },
    #   #   runtime: 0.012
    #   # }
    def call(severity, time, task, message, **options) # rubocop:disable Lint/UnusedMethodArgument
      m = message.is_a?(Result) ? message.to_h : {}

      if options.delete(:ansi_colorize) && message.is_a?(Result)
        COLORED_KEYS.each { |k| m[k] = ResultAnsi.call(m[k]) if m.key?(k) }
      elsif !message.is_a?(Result)
        m.merge!(TaskSerializer.call(task), message: message)
      end

      m[:origin] ||= "CMDx"
      m
    end

  end
end
