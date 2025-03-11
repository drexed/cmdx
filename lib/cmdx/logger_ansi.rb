# frozen_string_literal: true

module CMDx
  module LoggerAnsi

    SEVERITY_COLOR_CODES = {
      "D" => 34, # DEBUG - Blue
      "I" => 32, # INFO  - Green
      "W" => 33, # WARN  - Yellow
      "E" => 31, # ERROR - Red
      "F" => 35  # FATAL - Magenta
    }.freeze

    module_function

    def call(s)
      c = SEVERITY_COLOR_CODES[s[0]] || 39 # Default
      "\e[1;#{c}m#{s}\e[0m"
    end

  end
end
