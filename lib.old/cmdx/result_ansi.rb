# frozen_string_literal: true

module CMDx
  # ANSI color formatting utilities for result states and statuses.
  #
  # This module provides functionality to apply appropriate ANSI colors to
  # result states and statuses for enhanced terminal output visibility.
  # It maps different execution states and statuses to their corresponding
  # colors and delegates the actual color application to the AnsiColor utility.
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

    # Applies ANSI color formatting to a result state or status string.
    #
    # Takes a result state or status string and applies the appropriate ANSI
    # color formatting using the predefined color mappings. This provides
    # visual distinction for different execution outcomes in terminal output.
    #
    # @param s [String] the result state or status string to colorize
    #
    # @return [String] the input string with ANSI color codes applied
    #
    # @example Colorize a success status
    #   ResultAnsi.call("success") #=> "\e[0;32;49msuccess\e[0m" (green)
    #
    # @example Colorize a failed status
    #   ResultAnsi.call("failed") #=> "\e[0;31;49mfailed\e[0m" (red)
    #
    # @example Colorize an executing state
    #   ResultAnsi.call("executing") #=> "\e[0;33;49mexecuting\e[0m" (yellow)
    def call(s)
      Utils::AnsiColor.call(s, color: color(s))
    end

    # Determines the appropriate color for a result state or status.
    #
    # Looks up the color mapping for the given state or status string,
    # returning the corresponding color symbol or :default if no specific
    # mapping is found.
    #
    # @param s [String] the result state or status string to find color for
    #
    # @return [Symbol] the color symbol (:blue, :yellow, :green, :red, or :default)
    #
    # @example Get color for success status
    #   ResultAnsi.color("success") #=> :green
    #
    # @example Get color for unknown value
    #   ResultAnsi.color("unknown") #=> :default
    #
    # @example Get color for executing state
    #   ResultAnsi.color("executing") #=> :yellow
    def color(s)
      STATE_COLORS[s] || STATUS_COLORS[s] || :default
    end

  end
end
