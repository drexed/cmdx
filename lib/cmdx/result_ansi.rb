# frozen_string_literal: true

module CMDx
  # ANSI color formatting module for result states and statuses.
  #
  # The ResultAnsi module provides ANSI color formatting for result state and
  # status values to enhance readability in terminal output. It maps different
  # result states and statuses to appropriate colors for visual distinction.
  #
  # @example Basic result colorization
  #   ResultAnsi.call("complete")     # => Green colored text
  #   ResultAnsi.call("success")      # => Green colored text
  #   ResultAnsi.call("failed")       # => Red colored text
  #   ResultAnsi.call("interrupted")  # => Red colored text
  #
  # @example Usage in log formatters
  #   result_data = { state: "complete", status: "success" }
  #   colored_state = ResultAnsi.call(result_data[:state])
  #   colored_status = ResultAnsi.call(result_data[:status])
  #
  # @example Integration with pretty formatters
  #   # Used internally by PrettyLine, PrettyJson, PrettyKeyValue formatters
  #   formatted_status = ResultAnsi.call("failed")  # => Red "failed"
  #
  # @see CMDx::Result Result states and statuses
  # @see CMDx::Utils::AnsiColor ANSI color utility functions
  # @see CMDx::LogFormatters::PrettyLine Pretty line formatter with colors
  module ResultAnsi

    # Mapping of result states to ANSI colors.
    #
    # Maps Result state constants to their corresponding color codes
    # for consistent visual representation of execution states.
    STATE_COLORS = {
      Result::INITIALIZED => :blue,     # Initial state - blue
      Result::EXECUTING => :yellow,     # Currently executing - yellow
      Result::COMPLETE => :green,       # Successfully completed - green
      Result::INTERRUPTED => :red       # Execution interrupted - red
    }.freeze

    # Mapping of result statuses to ANSI colors.
    #
    # Maps Result status constants to their corresponding color codes
    # for consistent visual representation of execution outcomes.
    STATUS_COLORS = {
      Result::SUCCESS => :green,        # Successful completion - green
      Result::SKIPPED => :yellow,       # Intentionally skipped - yellow
      Result::FAILED => :red            # Failed execution - red
    }.freeze

    module_function

    # Applies ANSI color formatting to a result state or status string.
    #
    # Formats the input string with appropriate ANSI color codes based on
    # whether it matches a known result state or status value. Falls back
    # to default color for unknown values.
    #
    # @param s [String] The state or status string to colorize
    # @return [String] The string with ANSI color codes applied
    #
    # @example Colorizing result states
    #   ResultAnsi.call("initialized")  # => "\e[34minitialized\e[0m" (blue)
    #   ResultAnsi.call("executing")    # => "\e[33mexecuting\e[0m" (yellow)
    #   ResultAnsi.call("complete")     # => "\e[32mcomplete\e[0m" (green)
    #   ResultAnsi.call("interrupted")  # => "\e[31minterrupted\e[0m" (red)
    #
    # @example Colorizing result statuses
    #   ResultAnsi.call("success")      # => "\e[32msuccess\e[0m" (green)
    #   ResultAnsi.call("skipped")      # => "\e[33mskipped\e[0m" (yellow)
    #   ResultAnsi.call("failed")       # => "\e[31mfailed\e[0m" (red)
    #
    # @example Unknown value
    #   ResultAnsi.call("unknown")      # => "\e[39munknown\e[0m" (default color)
    #
    # @example Usage in result formatting
    #   result = ProcessOrderTask.call
    #   colored_state = ResultAnsi.call(result.state)
    #   colored_status = ResultAnsi.call(result.status)
    #   puts "Task #{colored_state} with #{colored_status}"
    #   # => "Task complete with success" (with appropriate colors)
    def call(s)
      color = STATE_COLORS[s] || STATUS_COLORS[s] || :default

      Utils::AnsiColor.call(s, color:)
    end

  end
end
