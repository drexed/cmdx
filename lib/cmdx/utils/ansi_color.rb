# frozen_string_literal: true

module CMDx
  module Utils
    # Utility for adding ANSI color codes to terminal output.
    #
    # AnsiColor provides methods to colorize text output in terminal
    # environments, supporting various colors and text modes for
    # enhanced readability of logs and console output. Used extensively
    # by CMDx's pretty formatters to provide visual distinction between
    # different log levels, statuses, and metadata.
    #
    # @example Basic color usage
    #   Utils::AnsiColor.call("Error", color: :red)
    #   # => "\e[0;31;49mError\e[0m"
    #
    # @example Color with text modes
    #   Utils::AnsiColor.call("Warning", color: :yellow, mode: :bold)
    #   Utils::AnsiColor.call("Info", color: :blue, mode: :underline)
    #
    # @example Log severity coloring
    #   Utils::AnsiColor.call("ERROR", color: :red, mode: :bold)
    #   Utils::AnsiColor.call("WARN", color: :yellow)
    #   Utils::AnsiColor.call("INFO", color: :blue)
    #   Utils::AnsiColor.call("DEBUG", color: :light_black)
    #
    # @example Status indicator coloring
    #   Utils::AnsiColor.call("success", color: :green, mode: :bold)
    #   Utils::AnsiColor.call("failed", color: :red, mode: :bold)
    #   Utils::AnsiColor.call("skipped", color: :yellow)
    #
    # @example Available colors
    #   Utils::AnsiColor.call("Text", color: :red)
    #   Utils::AnsiColor.call("Text", color: :green)
    #   Utils::AnsiColor.call("Text", color: :blue)
    #   Utils::AnsiColor.call("Text", color: :light_cyan)
    #   Utils::AnsiColor.call("Text", color: :magenta)
    #
    # @example Available text modes
    #   Utils::AnsiColor.call("Bold", color: :white, mode: :bold)
    #   Utils::AnsiColor.call("Italic", color: :white, mode: :italic)
    #   Utils::AnsiColor.call("Underline", color: :white, mode: :underline)
    #   Utils::AnsiColor.call("Strikethrough", color: :white, mode: :strike)
    #
    # @see CMDx::ResultAnsi Uses this for result status coloring
    # @see CMDx::LoggerAnsi Uses this for log severity coloring
    # @see CMDx::LogFormatters::PrettyLine Uses this for colorized log output
    # @see CMDx::LogFormatters::PrettyKeyValue Uses this for colorized key-value pairs
    module AnsiColor

      # Available color codes for text coloring.
      #
      # Maps color names to their corresponding ANSI escape code numbers.
      # Includes both standard and light variants of common colors for
      # flexible visual styling in terminal environments.
      #
      # @return [Hash<Symbol, Integer>] mapping of color names to ANSI codes
      COLOR_CODES = {
        black: 30,
        red: 31,
        green: 32,
        yellow: 33,
        blue: 34,
        magenta: 35,
        cyan: 36,
        white: 37,
        default: 39,
        light_black: 90,
        light_red: 91,
        light_green: 92,
        light_yellow: 93,
        light_blue: 94,
        light_magenta: 95,
        light_cyan: 96,
        light_white: 97
      }.freeze

      # Available text mode codes for formatting.
      #
      # Maps text formatting mode names to their corresponding ANSI escape
      # code numbers. Provides various text styling options including bold,
      # italic, underline, and other visual effects.
      #
      # @return [Hash<Symbol, Integer>] mapping of mode names to ANSI codes
      MODE_CODES = {
        default: 0,
        bold: 1,
        dim: 2,
        italic: 3,
        underline: 4,
        blink: 5,
        blink_slow: 5,
        blink_fast: 6,
        invert: 7,
        hide: 8,
        strike: 9,
        double_underline: 20,
        reveal: 28,
        overlined: 53
      }.freeze

      module_function

      # Apply ANSI color and mode formatting to text.
      #
      # Wraps the provided text with ANSI escape codes to apply the specified
      # color and formatting mode. The resulting string will display with the
      # requested styling in ANSI-compatible terminals and will gracefully
      # degrade in non-ANSI environments.
      #
      # @param value [String] text to colorize
      # @param color [Symbol] color name from COLOR_CODES
      # @param mode [Symbol] text mode from MODE_CODES (defaults to :default)
      # @return [String] text wrapped with ANSI escape codes
      # @raise [KeyError] if color or mode is not found in the respective code maps
      #
      # @example Success message with green bold text
      #   AnsiColor.call("Success", color: :green, mode: :bold)
      #   # => "\e[1;32;49mSuccess\e[0m"
      #
      # @example Error message with red text
      #   AnsiColor.call("Error", color: :red)
      #   # => "\e[0;31;49mError\e[0m"
      #
      # @example Warning with yellow underlined text
      #   AnsiColor.call("Warning", color: :yellow, mode: :underline)
      #   # => "\e[4;33;49mWarning\e[0m"
      #
      # @example Debug info with dimmed light text
      #   AnsiColor.call("Debug info", color: :light_black, mode: :dim)
      #   # => "\e[2;90;49mDebug info\e[0m"
      #
      # @example Invalid color raises KeyError
      #   AnsiColor.call("Text", color: :invalid_color)
      #   # => KeyError: key not found: :invalid_color
      #
      # @note The escape sequence format is: \e[{mode};{color};49m{text}\e[0m
      # @note The "49" represents the default background color
      # @note The final "\e[0m" resets all formatting to default
      def call(value, color:, mode: :default)
        color_code = COLOR_CODES.fetch(color)
        mode_code  = MODE_CODES.fetch(mode)

        "\e[#{mode_code};#{color_code};49m#{value}\e[0m"
      end

    end
  end
end
