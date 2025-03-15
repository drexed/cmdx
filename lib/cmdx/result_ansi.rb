# frozen_string_literal: true

module CMDx
  module ResultAnsi

    STATE_COLORS = {
      Result::INITIALIZED => :blue,
      Result::EXECUTING => :yellow,
      Result::COMPLETE => :green,
      Result::INTERRUPTED => :red
    }.freeze
    STATUS_COLORS = {
      Result::SUCCESS => :green,
      Result::SKIPPED => :yellow,
      Result::FAILED => :red
    }.freeze

    module_function

    def call(s)
      color = STATE_COLORS[s] || STATUS_COLORS[s] || :default

      Utils::AnsiColor.call(s, color:)
    end

  end
end
