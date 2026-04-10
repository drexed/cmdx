# frozen_string_literal: true

module CMDx
  # Checks task deprecation status and raises or warns accordingly.
  module Deprecator

    # @param task_class [Class]
    # @param config [Hash, Symbol, Boolean]
    #
    # @rbs (Class task_class, untyped config) -> void
    def self.check!(task_class, config)
      return unless config

      mode, message = parse(config, task_class)

      case mode
      when :restrict
        raise DeprecationError, message
      when :warn
        warn("[CMDx DEPRECATION] #{message}")
      end
    end

    # @rbs (untyped config, Class task_class) -> [Symbol, String]
    def self.parse(config, task_class)
      case config
      when ::Hash
        mode = config[:mode] || :warn
        msg = config[:message] || "#{task_class} is deprecated."
        msg += " Use #{config[:alternative]} instead." if config[:alternative]
        [mode, msg]
      when ::Symbol
        [config, "#{task_class} is deprecated."]
      else
        [:warn, "#{task_class} is deprecated."]
      end
    end

    private_class_method :parse

  end
end
