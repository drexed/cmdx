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
        if values.nil?
          raise ArgumentError, <<~MSG.chomp
            exclusion validator requires :in or :within (got #{options.keys.inspect}).
            See https://drexed.github.io/cmdx/inputs/validations/#exclusion
          MSG
        elsif values.is_a?(Hash)
          raise ArgumentError, <<~MSG.chomp
            exclusion validator :in/:within does not accept a Hash; pass an Array,
            Set, Range, or other Enumerable (e.g. `#{values.inspect}.keys`).
            See https://drexed.github.io/cmdx/inputs/validations/#exclusion
          MSG
        end

        if values.is_a?(Range)
          within_failure(values.begin, values.end, options) if values.cover?(value)
        elsif Array(values).any? { |v| v === value }
          of_failure(values, options)
        end
      end

      private

      def of_failure(values, options)
        values = values.map(&:inspect).join(", ")
        message = options[:of_message] || options[:message]
        message %= { values: } unless message.nil?

        Failure.new(message || I18nProxy.t("cmdx.validators.exclusion.of", values:))
      end

      def within_failure(min, max, options)
        message = options[:in_message] || options[:within_message] || options[:message]
        message %= { min:, max: } unless message.nil?

        Failure.new(message || I18nProxy.t("cmdx.validators.exclusion.within", min:, max:))
      end

    end
  end
end
