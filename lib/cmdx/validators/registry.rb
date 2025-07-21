# frozen_string_literal: true

module CMDx
  module Validators
    class Registry

      attr_reader :registry

      def initialize
        @registry = {
          exclusion: Exclusion,
          format: Format,
          inclusion: Inclusion,
          length: Length,
          numeric: Numeric,
          presence: Presence
        }
      end

      def register(name, validator)
        registry[name.to_sym] = validator
      end

      def [](name)
        registry[name.to_sym]
      end

    end
  end
end
