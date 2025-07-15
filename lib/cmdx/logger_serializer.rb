# frozen_string_literal: true

module CMDx
  # Serializes log messages for structured logging output.
  #
  # This module provides functionality to convert log messages into a structured
  # hash format suitable for various logging formatters. It handles special
  # processing for Result objects, including optional ANSI colorization of
  # specific keys and merging of task serialization data.
  module LoggerSerializer

    COLORED_KEYS = %i[
      state status outcome
    ].freeze

    module_function

    # Converts a log message into a structured hash format.
    #
    # Processes the message based on its type - if it's a Result object,
    # optionally colorizes specific keys. For non-Result messages, merges
    # task serialization data and the original message.
    #
    # @param _severity [String] The log severity level (unused but kept for compatibility)
    # @param _time [Time] The log timestamp (unused but kept for compatibility)
    # @param task [CMDx::Task] The task instance associated with the log message
    # @param message [Object] The message to be serialized (can be a Result or any object)
    # @param options [Hash] Additional options for serialization
    # @option options [Boolean] :ansi_colorize Whether to apply ANSI colorization to Result objects
    #
    # @return [Hash] A structured hash representation of the log message with origin set to "CMDx"
    #
    # @example Serializing a Result object with colorization
    #   result = CMDx::Result.new(task)
    #   LoggerSerializer.call("info", Time.now, task, result, ansi_colorize: true)
    #   # => { state: "\e[32msuccess\e[0m", status: "complete", origin: "CMDx", ... }
    #
    # @example Serializing a plain message
    #   LoggerSerializer.call("info", Time.now, task, "Processing user data")
    #   # => { index: 1, chain_id: "abc123", type: "Task", message: "Processing user data", origin: "CMDx", ... }
    def call(_severity, _time, task, message, **options)
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
