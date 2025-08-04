# frozen_string_literal: true

module CMDx
  module Utils
    module Ansi

      extend self

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

      def paint(value, color:, mode: :default)
        color_code = COLOR_CODES.fetch(color)
        mode_code  = MODE_CODES.fetch(mode)

        "\e[#{mode_code};#{color_code};49m#{value}\e[0m"
      end

    end
  end
end
