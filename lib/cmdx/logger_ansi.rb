# frozen_string_literal: true

module CMDx
  module LoggerAnsi

    SEVERITY_COLORS = {
      "D" => :blue,
      "I" => :green,
      "W" => :yellow,
      "E" => :red,
      "F" => :magenta
    }.freeze

    module_function

    def call(s)
      color = SEVERITY_COLORS[s[0]] || :default

      Utils::AnsiColor.call(s, color:, mode: :bold)
    end

  end
end
