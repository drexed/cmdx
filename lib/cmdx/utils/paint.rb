# frozen_string_literal: true

module CMDx
  module Utils
    module Paint

      extend self

      SEVERITY_COLORS = {
        "D" => :blue,      # DEBUG
        "I" => :green,     # INFO
        "W" => :yellow,    # WARN
        "E" => :red,       # ERROR
        "F" => :magenta    # FATAL
      }.freeze
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

      def severity(value, mode: :default)
        color_code = SEVERITY_COLORS.fetch(value[0])
        Ansi.paint(value, color: color_code, mode:)
      end

      def state(value, mode: :default)
        color_code = STATE_COLORS.fetch(value)
        Ansi.paint(value, color: color_code, mode:)
      end

      def status(value, mode: :default)
        color_code = STATUS_COLORS.fetch(value)
        Ansi.paint(value, color: color_code, mode:)
      end

    end
  end
end
