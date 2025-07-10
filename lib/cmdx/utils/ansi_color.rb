# frozen_string_literal: true

module CMDx
  module Utils
    # Utility module for applying ANSI color and formatting codes to text.
    #
    # This module provides functionality to colorize and format text output
    # using ANSI escape sequences, supporting various colors and text modes.
    #
    # @since 1.0.0
    module AnsiColor

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

      # Applies ANSI color and formatting to the given text value.
      #
      # @param value [String] the text to format with ANSI codes
      # @param color [Symbol] the color to apply (must be a key in COLOR_CODES)
      # @param mode [Symbol] the formatting mode to apply (must be a key in MODE_CODES)
      #
      # @return [String] the formatted text with ANSI escape sequences
      #
      # @raise [KeyError] if the specified color or mode is not found in the respective code maps
      #
      # @example Basic color application
      #   AnsiColor.call("Hello", color: :red) #=> "\e[0;31;49mHello\e[0m"
      #
      # @example Color with formatting mode
      #   AnsiColor.call("Warning", color: :yellow, mode: :bold) #=> "\e[1;33;49mWarning\e[0m"
      def call(value, color:, mode: :default)
        color_code = COLOR_CODES.fetch(color)
        mode_code  = MODE_CODES.fetch(mode)

        "\e[#{mode_code};#{color_code};49m#{value}\e[0m"
      end

    end
  end
end
