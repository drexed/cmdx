# frozen_string_literal: true

module CMDx
  # Handles deprecation warnings and restrictions for tasks.
  module Deprecator

    # Checks deprecation settings and raises or warns accordingly.
    #
    # @param task_class [Class] the task class to check
    #
    # @raise [DeprecationError] when :restrict mode is active
    #
    # @rbs (untyped task_class) -> void
    def self.check!(task_class)
      config = task_class.task_settings.resolved_deprecate
      return unless config

      message = deprecation_message(task_class, config)

      case config[:mode]&.to_sym
      when :restrict
        raise DeprecationError, message
      when :warn
        warn("[DEPRECATED] #{message}")
      end
    end

    # @rbs (untyped task_class, Hash[Symbol, untyped] config) -> String
    def self.deprecation_message(task_class, config)
      msg = "#{task_class.name} is deprecated"
      msg += ": #{config[:message]}" if config[:message]
      msg += " (use #{config[:alternative]} instead)" if config[:alternative]
      msg
    end

  end
end
