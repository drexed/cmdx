# frozen_string_literal: true

module CMDx
  module Utils
    module ColorSeverity

      COLOR_CODES = {
        "D" => 34, # DEBUG - Blue
        "I" => 32, # INFO - Green
        "W" => 33, # WARN - Yellow
        "E" => 31, # ERROR - Red
        "F" => 30  # FATAL - Black
      }.freeze

      module_function

      def call(severity)
        code = COLOR_CODES[severity[0]]
        "\e[1;#{code}m#{severity}\e[0m"
      end

    end
  end
end
