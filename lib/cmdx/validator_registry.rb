# frozen_string_literal: true

module CMDx
  class ValidatorRegistry

    extend Forwardable

    attr_reader :registry
    alias to_h registry

    def_delegators :registry, :keys

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

    def deregister(name)
      registry.delete(name.to_sym)
      self
    end

    def validate(type, task, value, options = {})
      raise TypeError, "unknown validator type #{type.inspect}" unless registry.key?(type)

      match =
        if options.is_a?(Hash)
          case options
          in allow_nil: then allow_nil && value.nil?
          else Utils::Condition.evaluate(task, options, value)
          end
        else
          options
        end

      return unless match

      Utils::Call.invoke(task, registry[type], value, options)
    end

  end
end
