# frozen_string_literal: true

module CMDx
  # ANSI color formatting utilities for log severity levels.
  #
  # This module provides functionality to apply ANSI color codes to log messages
  # based on their severity level. It maps standard log severity indicators to
  # appropriate colors for enhanced readability in terminal output.
  module LoggerAnsi

    SEVERITY_COLORS = {
      "D" => :blue,      # DEBUG
      "I" => :green,     # INFO
      "W" => :yellow,    # WARN
      "E" => :red,       # ERROR
      "F" => :magenta    # FATAL
    }.freeze

    module_function

    # Applies ANSI color formatting to a log message based on its severity level.
    #
    # @param s [String] the log message string to format
    #
    # @return [String] the formatted message with ANSI color codes applied
    #
    # @example Format a debug message
    #   CMDx::LoggerAnsi.call("DEBUG: Starting process") #=> "\e[1;34;49mDEBUG: Starting process\e[0m"
    #
    # @example Format an error message
    #   CMDx::LoggerAnsi.call("ERROR: Connection failed") #=> "\e[1;31;49mERROR: Connection failed\e[0m"
    def call(s)
      Utils::AnsiColor.call(s, color: color(s), mode: :bold)
    end

    # Determines the appropriate color for a log message based on its severity level.
    #
    # @param s [String] the log message string to analyze
    #
    # @return [Symbol] the color symbol corresponding to the severity level
    #
    # @example Get color for debug message
    #   CMDx::LoggerAnsi.color("DEBUG: message") #=> :blue
    #
    # @example Get color for unknown severity
    #   CMDx::LoggerAnsi.color("UNKNOWN: message") #=> :default
    def color(s)
      SEVERITY_COLORS[s[0]] || :default
    end

  end
end
