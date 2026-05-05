# frozen_string_literal: true

module CMDx
  class Validators
    # Validates that a value is within an enumerable or `Range`. Range uses
    # `#cover?`; other enumerables use `===` (so regex/class matchers work).
    module Inclusion

      extend self

      # @param value [Object]
      # @param options [Hash{Symbol => Object}]
      # @option options [Range, Array, Set, Enumerable] :in allowed values
      # @option options [Range, Array, Set, Enumerable] :within alias for `:in`
      # @option options [String] :message global failure-message override
      # @option options [String] :of_message override for enumerable failures
      # @option options [String] :in_message, :within_message overrides for range failures
      # @return [Validators::Failure, nil]
      # @raise [ArgumentError] when neither `:in` nor `:within` is given
      def call(value, options = EMPTY_HASH)
        values = options[:in] || options[:within]
        raise ArgumentError, "inclusion validator requires :in or :within option" if values.nil?

        if values.is_a?(Range)
          within_failure(values.begin, values.end, options) unless values.cover?(value)
        elsif Array(values).none? { |v| v === value }
          of_failure(values, options)
        end
      end

      private

      # @param values [Enumerable] collection rendered into the failure message
      # @param options [Hash{Symbol => Object}]
      # @option options [String] :of_message
      # @option options [String] :message
      # @return [Validators::Failure]
      def of_failure(values, options)
        values = values.map(&:inspect).join(", ")
        message = options[:of_message] || options[:message]
        message %= { values: } unless message.nil?

        Failure.new(message || I18nProxy.t("cmdx.validators.inclusion.of", values:))
      end

      # @param min [Object] range/inclusion lower bound
      # @param max [Object] range/inclusion upper bound
      # @param options [Hash{Symbol => Object}]
      # @option options [String] :in_message
      # @option options [String] :within_message
      # @option options [String] :message
      # @return [Validators::Failure]
      def within_failure(min, max, options)
        message = options[:in_message] || options[:within_message] || options[:message]
        message %= { min:, max: } unless message.nil?

        Failure.new(message || I18nProxy.t("cmdx.validators.inclusion.within", min:, max:))
      end

    end
  end
end
