# frozen_string_literal: true

module CMDx
  module ResultAnsi

    STATE_COLORS = {
      Result::INITIALIZED => :blue,     # Initial state - blue
      Result::EXECUTING => :yellow,     # Currently executing - yellow
      Result::COMPLETE => :green,       # Successfully completed - green
      Result::INTERRUPTED => :red       # Execution interrupted - red
    }.freeze
    STATUS_COLORS = {
      Result::SUCCESS => :green,        # Successful completion - green
      Result::SKIPPED => :yellow,       # Intentionally skipped - yellow
      Result::FAILED => :red            # Failed execution - red
    }.freeze

    module_function

    def call(s)
      Utils::AnsiColor.call(s, color: color(s))
    end

    def color(s)
      STATE_COLORS[s] || STATUS_COLORS[s] || :default
    end

  end
end
