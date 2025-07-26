# frozen_string_literal: true

module CMDx
  class ValidatorRegistry

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

  end
end
