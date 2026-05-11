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
      def call(value, options = EMPTY_HASH)
        match =
          case options
          in with:, without:
            value&.match?(with) && !value&.match?(without)
          in with:
            value&.match?(with)
          in without:
            !value&.match?(without)
          else
            raise ArgumentError,
              "format validator requires :with and/or :without (got #{options.keys.inspect}). " \
              "See https://drexed.github.io/cmdx/inputs/validations/"
          end

        return if match

        Failure.new(options[:message] || I18nProxy.t("cmdx.validators.format"))
      end

    end
  end
end
