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
        !!options[:required]
      end

      def source
        @_source ||= options[:source] || parent&.signature || :context
      end

      def signature
        @_signature ||= Utils::Signature.call(source, name, options)
      end

    end
  end
end
