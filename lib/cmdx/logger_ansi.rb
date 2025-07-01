# frozen_string_literal: true

module CMDx
  # ANSI color formatting module for logger severity levels.
  #
  # The LoggerAnsi module provides ANSI color formatting for log severity levels
  # to enhance readability in terminal output. Each severity level is assigned
  # a specific color and bold formatting to make log messages more visually
  # distinguishable.
  #
  # @example Basic severity colorization
  #   LoggerAnsi.call("DEBUG message")    # => Blue bold text
  #   LoggerAnsi.call("INFO message")     # => Green bold text
  #   LoggerAnsi.call("WARN message")     # => Yellow bold text
  #   LoggerAnsi.call("ERROR message")    # => Red bold text
  #   LoggerAnsi.call("FATAL message")    # => Magenta bold text
  #
  # @example Usage in log formatters
  #   class CustomFormatter
  #     def call(severity, time, progname, msg)
  #       colored_severity = LoggerAnsi.call(severity)
  #       "#{colored_severity} #{msg}"
  #     end
  #   end
  #
  # @example Integration with pretty formatters
  #   # Used internally by PrettyLine, PrettyJson, PrettyKeyValue formatters
  #   formatted_severity = LoggerAnsi.call("ERROR")  # => Red bold "ERROR"
  #
  # @see CMDx::Utils::AnsiColor ANSI color utility functions
  # @see CMDx::LogFormatters::PrettyLine Pretty line formatter with colors
  # @see CMDx::LogFormatters::PrettyJson Pretty JSON formatter with colors
  module LoggerAnsi

    # Mapping of log severity levels to ANSI colors.
    #
    # Maps the first character of severity levels to their corresponding
    # color codes for consistent visual representation across log output.
    SEVERITY_COLORS = {
      "D" => :blue,      # DEBUG
      "I" => :green,     # INFO
      "W" => :yellow,    # WARN
      "E" => :red,       # ERROR
      "F" => :magenta    # FATAL
    }.freeze

    module_function

    # Applies ANSI color formatting to a severity string.
    #
    # Formats the input string with appropriate ANSI color codes based on
    # the first character of the string, which typically represents the
    # log severity level. All formatted text is rendered in bold.
    #
    # @param s [String] The severity string to colorize
    # @return [String] The string with ANSI color codes applied
    #
    # @example Colorizing different severity levels
    #   LoggerAnsi.call("DEBUG")  # => "\e[1;34mDEBUG\e[0m" (blue bold)
    #   LoggerAnsi.call("INFO")   # => "\e[1;32mINFO\e[0m" (green bold)
    #   LoggerAnsi.call("WARN")   # => "\e[1;33mWARN\e[0m" (yellow bold)
    #   LoggerAnsi.call("ERROR")  # => "\e[1;31mERROR\e[0m" (red bold)
    #   LoggerAnsi.call("FATAL")  # => "\e[1;35mFATAL\e[0m" (magenta bold)
    #
    # @example Unknown severity level
    #   LoggerAnsi.call("CUSTOM") # => "\e[1;39mCUSTOM\e[0m" (default color bold)
    #
    # @example Full log message formatting
    #   severity = "ERROR"
    #   message = "Task failed with validation errors"
    #   colored_severity = LoggerAnsi.call(severity)
    #   log_line = "#{colored_severity}: #{message}"
    #   # => "\e[1;31mERROR\e[0m: Task failed with validation errors"
    def call(s)
      Utils::AnsiColor.call(s, color: color(s), mode: :bold)
    end

    # Determines the appropriate color for a severity string.
    #
    # Extracts the first character from the severity string and maps it to
    # the corresponding color symbol using the SEVERITY_COLORS hash. If no
    # mapping is found for the first character, returns the default color.
    #
    # @param s [String] The severity string to determine color for
    # @return [Symbol] The color symbol for the severity level
    #
    # @example Mapping severity levels to colors
    #   color("DEBUG")    # => :blue
    #   color("INFO")     # => :green
    #   color("WARN")     # => :yellow
    #   color("ERROR")    # => :red
    #   color("FATAL")    # => :magenta
    #
    # @example Unknown severity level
    #   color("CUSTOM")   # => :default
    #   color("TRACE")    # => :default
    #
    # @example Case sensitivity
    #   color("debug")    # => :default (lowercase 'd' not mapped)
    #   color("Debug")    # => :blue (uppercase 'D' is mapped)
    #
    # @note This method only considers the first character of the input string
    # @see SEVERITY_COLORS The mapping hash used for color determination
    def color(s)
      SEVERITY_COLORS[s[0]] || :default
    end

  end
end
