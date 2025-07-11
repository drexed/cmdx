# frozen_string_literal: true

module CMDx
  module LoggerAnsi

    SEVERITY_COLORS = {
      "D" => :blue,      # DEBUG
      "I" => :green,     # INFO
      "W" => :yellow,    # WARN
      "E" => :red,       # ERROR
      "F" => :magenta    # FATAL
    }.freeze

    module_function

    def call(s)
      Utils::AnsiColor.call(s, color: color(s), mode: :bold)
    end

    def color(s)
      SEVERITY_COLORS[s[0]] || :default
    end

  end
end
