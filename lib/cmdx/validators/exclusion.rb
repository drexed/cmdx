# frozen_string_literal: true

module CMDx
  class Validators
    # Inverse of {Inclusion}: the value must not be within the given
    # enumerable or `Range`.
    module Exclusion

      extend self

      # @param value [Object]
      # @param options [Hash{Symbol => Object}]
      # @option options [Range, Array, Set, Enumerable] :in disallowed values
      # @option options [Range, Array, Set, Enumerable] :within alias for `:in`
      # @option options [String] :message global failure-message override
      # @option options [String] :of_message override for enumerable failures
      # @option options [String] :in_message, :within_message overrides for range failures
      # @return [Validators::Failure, nil]
      # @raise [ArgumentError] when neither `:in` nor `:within` is given
      def call(value, options = EMPTY_HASH)
        values = options[:in] || options[:within]
        raise ArgumentError, "exclusion validator requires :in or :within option" if values.nil?

        if values.is_a?(Range)
          within_failure(values.begin, values.end, options) if values.cover?(value)
        elsif Array(values).any? { |v| v === value }
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

        Failure.new(message || I18nProxy.t("cmdx.validators.exclusion.of", values:))
      end

      # @param min [Object] range/exclusion lower bound
      # @param max [Object] range/exclusion upper bound
      # @param options [Hash{Symbol => Object}]
      # @option options [String] :in_message
      # @option options [String] :within_message
      # @option options [String] :message
      # @return [Validators::Failure]
      def within_failure(min, max, options)
        message = options[:in_message] || options[:within_message] || options[:message]
        message %= { min:, max: } unless message.nil?

        Failure.new(message || I18nProxy.t("cmdx.validators.exclusion.within", min:, max:))
      end

    end
  end
end
