# frozen_string_literal: true

module CMDx
  module Coercions
    class Registry

      extend Forwardable

      def_delegators :coercions, :each, :[]

      attr_reader :coercions

      def initialize(coercions = nil)
        @coercions = coercions || {
          array: Coercions::Array,
          big_decimal: Coercions::BigDecimal,
          boolean: Coercions::Boolean,
          complex: Coercions::Complex,
          date: Coercions::Date,
          datetime: Coercions::DateTime,
          float: Coercions::Float,
          hash: Coercions::Hash,
          integer: Coercions::Integer,
          rational: Coercions::Rational,
          string: Coercions::String,
          time: Coercions::Time
        }
      end

      def dup
        self.class.new(coercions.dup)
      end

      def register(name, coercion)
        coercions[name.to_sym] = coercion
      end

    end
  end
end
