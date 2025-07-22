# frozen_string_literal: true

module CMDx
  module Parameters
    class Attribute

      attr_reader :name, :options

      def initialize(name, options = {})
        @name    = name
        @options = options
      end

      def required?
        options[:required]
      end

      def optional?
        !required?
      end

    end
  end
end
