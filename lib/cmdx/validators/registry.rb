# frozen_string_literal: true

module CMDx
  module Validators
    class Registry

      extend Forwardable

      def_delegators :validators, :each, :[]

      attr_accessor :validators

      def initialize(validators = nil)
        @validators = validators || {
          exclusion: Validators::Exclusion,
          format: Validators::Format,
          inclusion: Validators::Inclusion,
          length: Validators::Length,
          numeric: Validators::Numeric,
          presence: Validators::Presence
        }
      end

      def dup
        self.class.new(validators.dup)
      end

      def register(name, validator)
        validators[name.to_sym] = validator
      end

    end
  end
end
