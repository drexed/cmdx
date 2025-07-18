# frozen_string_literal: true

module CMDx
  # ANSI color formatting for result states and statuses.
  #
  # This module provides functionality to apply appropriate ANSI color codes
  # to result states and statuses for enhanced console output readability.
  # It maps execution states and completion statuses to corresponding colors
  # and provides methods to format strings with these colors.
  module ResultAnsi

    STATE_COLORS = {
      Result::INITIALIZED => :blue,     # Initial state - blue
      Result::EXECUTING => :yellow,     # Currently executing - yellow
      Result::COMPLETE => :green,       # Successfully completed - green
      Result::INTERRUPTED => :red       # Execution interrupted - red
    }.freeze
    STATUS_COLORS = {
      Result::SUCCESS => :green,        # Successful completion - green
      Result::SKIPPED => :yellow,       # Intentionally skipped - yellow
      Result::FAILED => :red            # Failed execution - red
    }.freeze

    module_function

    # Applies ANSI color formatting to a string based on its state or status.
    #
    # @param s [String] the string to format with ANSI color codes
    #
    # @return [String] the formatted string with appropriate ANSI color codes
    #
    # @example Format a result state
    #   ResultAnsi.call(Result::EXECUTING) #=> "\e[0;33;49mexecuting\e[0m"
    #
    # @example Format a result status
    #   ResultAnsi.call(Result::SUCCESS) #=> "\e[0;32;49msuccess\e[0m"
    def call(s)
      Utils::AnsiColor.call(s, color: color(s))
    end

    # Determines the appropriate ANSI color for a given state or status.
    #
    # @param s [String] the state or status string to determine color for
    #
    # @return [Symbol] the color symbol corresponding to the state/status, or :default if not found
    #
    # @example Get color for a state
    #   ResultAnsi.color(Result::COMPLETE) #=> :green
    #
    # @example Get color for unknown value
    #   ResultAnsi.color("unknown") #=> :default
    def color(s)
      STATE_COLORS[s] || STATUS_COLORS[s] || :default
    end

  end
end
