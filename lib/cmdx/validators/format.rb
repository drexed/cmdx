# frozen_string_literal: true

module CMDx
  class Validators
    # Validates that a value matches a `:with` regex and/or does not match a
    # `:without` regex. Both may be combined; at least one is required.
    module Format

      extend self

      # @param value [String, nil]
      # @param options [Hash{Symbol => Object}]
      # @option options [Regexp] :with must match
      # @option options [Regexp] :without must not match
      # @option options [String] :message override for the failure message
      # @return [Validators::Failure, nil]
      # @raise [ArgumentError] when neither `:with` nor `:without` is given
      # @note Non-String values that do not respond to `#match?` fail with the
      #   regular format failure rather than raise `NoMethodError`. Coerce inputs
      #   to String beforehand when format checks are required.
      def call(value, options = EMPTY_HASH)
        str = value.nil? || value.respond_to?(:match?) ? value : value.to_s

        match =
          case options
          in with:, without:
            str&.match?(with) && !str&.match?(without)
          in with:
            str&.match?(with)
          in without:
            !str&.match?(without)
          else
            raise ArgumentError, <<~MSG.chomp
              format validator requires :with and/or :without (got #{options.keys.inspect}).
              See https://drexed.github.io/cmdx/inputs/validations/#format
            MSG
          end

        return if match

        Failure.new(options[:message] || I18nProxy.t("cmdx.validators.format"))
      end

    end
  end
end
