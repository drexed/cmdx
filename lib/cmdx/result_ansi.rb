# frozen_string_literal: true

module CMDx
  module ResultAnsi

    STATE_COLOR_CODES = {
      Result::INITIALIZED => 34, # Blue
      Result::EXECUTING => 33,   # Yellow
      Result::COMPLETE => 32,    # Green
      Result::INTERRUPTED => 31  # Red
    }.freeze
    STATUS_COLOR_CODES = {
      Result::SUCCESS => 32, # Green
      Result::SKIPPED => 33, # Yellow
      Result::FAILED => 31   # Red
    }.freeze

    module_function

    def call(s)
      c = STATE_COLOR_CODES[s] || STATUS_COLOR_CODES[s] || 39 # Default
      "\e[1;#{c}m#{s}\e[0m"
    end

  end
end
