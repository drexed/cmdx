# frozen_string_literal: true

module CMDx
  # Logger message serialization module for structured log output.
  #
  # The LoggerSerializer module provides functionality to serialize log messages
  # into structured hash format suitable for various log formatters. It handles
  # different message types including Result objects and plain messages, with
  # optional ANSI colorization for terminal output.
  #
  # @example Basic message serialization
  #   task = ProcessOrderTask.new
  #   message = "Processing order 123"
  #
  #   LoggerSerializer.call(:info, Time.now, task, message)
  #   # => {
  #   #   origin: "CMDx",
  #   #   index: 0,
  #   #   chain_id: "...",
  #   #   type: "Task",
  #   #   class: "ProcessOrderTask",
  #   #   id: "...",
  #   #   tags: [],
  #   #   message: "Processing order 123"
  #   # }
  #
  # @example Result object serialization
  #   result = task.result  # CMDx::Result instance
  #
  #   LoggerSerializer.call(:info, Time.now, task, result)
  #   # => {
  #   #   origin: "CMDx",
  #   #   state: "complete",
  #   #   status: "success",
  #   #   outcome: "success",
  #   #   metadata: {},
  #   #   runtime: 0.5,
  #   #   index: 0,
  #   #   chain_id: "...",
  #   #   # ... other result data
  #   # }
  #
  # @example Colorized result serialization
  #   LoggerSerializer.call(:info, Time.now, task, result, ansi_colorize: true)
  #   # => Same as above but with ANSI color codes in state/status/outcome values
  #
  # @see CMDx::Result Result object structure and data
  # @see CMDx::TaskSerializer Task serialization functionality
  # @see CMDx::ResultAnsi Result ANSI colorization
  module LoggerSerializer

    # Keys that should be colorized when ANSI colorization is enabled.
    #
    # These keys represent result state information that benefits from
    # color coding in terminal output for better visual distinction.
    COLORED_KEYS = %i[
      state status outcome
    ].freeze

    module_function

    # Serializes a log message into a structured hash format.
    #
    # Converts log messages into hash format suitable for structured logging.
    # Handles both Result objects and plain messages differently, with optional
    # ANSI colorization for terminal-friendly output.
    #
    # @param _severity [Symbol] Log severity level (not used in current implementation)
    # @param _time [Time] Log timestamp (not used in current implementation)
    # @param task [CMDx::Task] The task instance generating the log message
    # @param message [Object] The message to serialize (Result object or other)
    # @param options [Hash] Serialization options
    # @option options [Boolean] :ansi_colorize (false) Whether to apply ANSI colors
    # @return [Hash] Structured hash representation of the log message
    #
    # @example Plain message serialization
    #   LoggerSerializer.call(:info, Time.now, task, "Task started")
    #   # => {
    #   #   origin: "CMDx",
    #   #   index: 0,
    #   #   chain_id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
    #   #   type: "Task",
    #   #   class: "MyTask",
    #   #   id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
    #   #   tags: [],
    #   #   message: "Task started"
    #   # }
    #
    # @example Result object serialization
    #   result = CMDx::Result.new(task)
    #   result.complete!
    #
    #   LoggerSerializer.call(:info, Time.now, task, result)
    #   # => {
    #   #   origin: "CMDx",
    #   #   state: "complete",
    #   #   status: "success",
    #   #   outcome: "success",
    #   #   metadata: {},
    #   #   runtime: 0.001,
    #   #   index: 0,
    #   #   chain_id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
    #   #   type: "Task",
    #   #   class: "MyTask",
    #   #   id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
    #   #   tags: []
    #   # }
    #
    # @example Colorized result serialization
    #   LoggerSerializer.call(:info, Time.now, task, result, ansi_colorize: true)
    #   # => Same as above but state/status/outcome values contain ANSI color codes
    #   # => { state: "\e[32mcomplete\e[0m", status: "\e[32msuccess\e[0m", ... }
    #
    # @example Hash-like message object
    #   custom_message = OpenStruct.new(action: "process", item_id: 123)
    #   LoggerSerializer.call(:debug, Time.now, task, custom_message)
    #   # => {
    #   #   origin: "CMDx",
    #   #   action: "process",
    #   #   item_id: 123,
    #   #   index: 0,
    #   #   chain_id: "...",
    #   #   type: "Task",
    #   #   class: "MyTask",
    #   #   id: "...",
    #   #   tags: []
    #   # }
    def call(_severity, _time, task, message, **options)
      m = message.respond_to?(:to_h) ? message.to_h : {}

      if options.delete(:ansi_colorize) && message.is_a?(Result)
        COLORED_KEYS.each { |k| m[k] = ResultAnsi.call(m[k]) if m.key?(k) }
      elsif !message.is_a?(Result)
        m.merge!(
          TaskSerializer.call(task),
          message: message
        )
      end

      m[:origin] ||= "CMDx"
      m
    end

  end
end
