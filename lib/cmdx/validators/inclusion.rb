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
        if values.nil?
          raise ArgumentError, <<~MSG.chomp
            inclusion validator requires :in or :within (got #{options.keys.inspect}).
            See https://drexed.github.io/cmdx/inputs/validations/#inclusion
          MSG
        end

        if values.is_a?(Range)
          within_failure(values.begin, values.end, options) unless values.cover?(value)
        elsif Array(values).none? { |v| v === value }
          of_failure(values, options)
        end
      end

      private

      def of_failure(values, options)
        values = values.map(&:inspect).join(", ")
        message = options[:of_message] || options[:message]
        message %= { values: } unless message.nil?

        Failure.new(message || I18nProxy.t("cmdx.validators.inclusion.of", values:))
      end

      def within_failure(min, max, options)
        message = options[:in_message] || options[:within_message] || options[:message]
        message %= { min:, max: } unless message.nil?

        Failure.new(message || I18nProxy.t("cmdx.validators.inclusion.within", min:, max:))
      end

    end
  end
end
