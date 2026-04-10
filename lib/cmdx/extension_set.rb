# frozen_string_literal: true

module CMDx
  # Coercions, validators, and middleware entries merged along the inheritance chain.
  class ExtensionSet

    # @return [Hash{Symbol => Proc}]
    attr_reader :coercions

    # @return [Hash{Symbol => Proc}]
    attr_reader :validators

    # @return [Array<Array(Object, Hash)>] middleware callable and options pairs
    attr_reader :middleware

    # @param coercions [Hash{Symbol => Proc}]
    # @param validators [Hash{Symbol => Proc}]
    # @param middleware [Array]
    def initialize(coercions: {}, validators: {}, middleware: [])
      @coercions = coercions.transform_keys(&:to_sym).freeze
      @validators = validators.transform_keys(&:to_sym).freeze
      @middleware = middleware.dup.freeze
      freeze
    end

    # @param other [ExtensionSet]
    # @return [ExtensionSet]
    def merge(other)
      self.class.new(
        coercions: @coercions.merge(other.coercions),
        validators: @validators.merge(other.validators),
        middleware: @middleware + other.middleware
      )
    end

    # @return [ExtensionSet]
    def self.build_defaults
      new(
        coercions: default_coercions,
        validators: default_validators,
        middleware: []
      )
    end

    # @return [Hash{Symbol => Proc}]
    def self.default_coercions
      {
        array: wrap_coercion(Coercions::Array),
        big_decimal: wrap_coercion(Coercions::BigDecimal),
        boolean: wrap_coercion(Coercions::Boolean),
        complex: wrap_coercion(Coercions::Complex),
        date: wrap_coercion(Coercions::Date),
        datetime: wrap_coercion(Coercions::DateTime),
        float: wrap_coercion(Coercions::Float),
        hash: wrap_coercion(Coercions::Hash),
        integer: wrap_coercion(Coercions::Integer),
        rational: wrap_coercion(Coercions::Rational),
        string: wrap_coercion(Coercions::String),
        symbol: wrap_coercion(Coercions::Symbol),
        time: wrap_coercion(Coercions::Time)
      }
    end

    # @return [Hash{Symbol => Proc}]
    def self.default_validators
      {
        absence: wrap_validator(Validators::Absence),
        exclusion: wrap_validator(Validators::Exclusion),
        format: wrap_validator(Validators::Format),
        inclusion: wrap_validator(Validators::Inclusion),
        length: wrap_validator(Validators::Length),
        numeric: wrap_validator(Validators::Numeric),
        presence: wrap_validator(Validators::Presence)
      }
    end

    # @param mod [Module]
    # @return [Proc]
    def self.wrap_coercion(mod)
      lambda do |value, **kwargs|
        mod.call(value, kwargs.except(:context, :attribute))
      end
    end

    # @param mod [Module]
    # @return [Proc]
    def self.wrap_validator(mod)
      lambda do |value, **kwargs|
        mod.call(value, kwargs.except(:context, :attribute))
      end
    end

  end
end
