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
    end

    def call(type, attribute, options)
      case validator = registry[type]
      when Symbol, String
        attribute.task.send(validator, attribute, options)
      when Validator, Proc
        validator.call(attribute, options)
      else
        raise UnknownValidatorError, "unknown validator #{type}"
      end
    end

  end
end
