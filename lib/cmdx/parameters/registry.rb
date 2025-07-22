# frozen_string_literal: true

module CMDx
  module Parameters
    class Registry

      extend Forwardable

      def_delegators :attributes, :each

      attr_reader :attributes, :errors

      def initialize
        @attributes = []
        @errors = Errors.new
      end

      def register(attribute)
        @attributes << attribute
      end

    end
  end
end
