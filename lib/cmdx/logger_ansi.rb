# frozen_string_literal: true

module CMDx
  # ANSI color formatting for logger severity levels and text output.
  #
  # LoggerAnsi provides utility methods for applying ANSI color codes to logger
  # severity indicators and general text formatting. It maps standard logger
  # severity levels to appropriate colors for enhanced readability in terminal output,
  # delegating actual color application to the AnsiColor utility module.
  module LoggerAnsi

    SEVERITY_COLORS = {
      "D" => :blue,      # DEBUG
      "I" => :green,     # INFO
      "W" => :yellow,    # WARN
      "E" => :red,       # ERROR
      "F" => :magenta    # FATAL
    }.freeze

    module_function

    # Applies ANSI color formatting to text based on severity level indication.
    #
    # This method extracts the color for the given text based on its first character
    # (typically a severity indicator) and applies both the determined color and bold
    # formatting using the AnsiColor utility. The method provides consistent color
    # formatting for logger output across the CMDx framework.
    #
    # @param s [String] the text to format, typically starting with a severity indicator
    #
    # @return [String] the formatted text with ANSI color and bold styling applied
    #
    # @example Format debug severity text
    #   LoggerAnsi.call("DEBUG: Starting process") #=> "\e[1;34;49mDEBUG: Starting process\e[0m"
    #
    # @example Format error severity text
    #   LoggerAnsi.call("ERROR: Operation failed") #=> "\e[1;31;49mERROR: Operation failed\e[0m"
    #
    # @example Format text with unknown severity
    #   LoggerAnsi.call("CUSTOM: Message") #=> "\e[1;39;49mCUSTOM: Message\e[0m"
    def call(s)
      Utils::AnsiColor.call(s, color: color(s), mode: :bold)
    end

    # Determines the appropriate color for text based on its severity indicator.
    #
    # This method extracts the first character from the provided text and maps it
    # to a corresponding color defined in SEVERITY_COLORS. If no matching severity
    # is found, it returns the default color to ensure consistent formatting behavior.
    #
    # @param s [String] the text to analyze, typically starting with a severity indicator
    #
    # @return [Symbol] the color symbol corresponding to the severity level, or :default if not found
    #
    # @example Get color for debug severity
    #   LoggerAnsi.color("DEBUG: Message") #=> :blue
    #
    # @example Get color for error severity
    #   LoggerAnsi.color("ERROR: Failed") #=> :red
    #
    # @example Get color for unknown severity
    #   LoggerAnsi.color("UNKNOWN: Text") #=> :default
    def color(s)
      SEVERITY_COLORS[s[0]] || :default
    end

  end
end
