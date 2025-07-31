# frozen_string_literal: true

module CMDx
  class ValidatorRegistry

    extend Forwardable

    def_delegators :registry, :keys

    attr_reader :registry

    def initialize(registry = nil)
      @registry = registry || {
        exclusion: Validators::Exclusion,
        format: Validators::Format,
        inclusion: Validators::Inclusion,
        length: Validators::Length,
        numeric: Validators::Numeric,
        presence: Validators::Presence
      }
    end

    def dup
      self.class.new(registry.dup)
    end

    def register(name, validator)
      registry[name.to_sym] = validator
      self
    end

    def validate!(type, task, value, options = {})
      raise UnknownValidationError, "unknown validator #{type}" unless registry.key?(type)

      case validator = registry[type]
      when Symbol, String then task.send(validator, value, options)
      else validator.call(value, options)
      end
    end

  end
end
