# frozen_string_literal: true

module CMDx
  class Validators
    # Validates the `#length` of `value` against one of: `:within` /
    # `:not_within` / `:in` / `:not_in` (Range), `:min` + `:max`,
    # `:gt` / `:lt` (strict comparison), or `:is` / `:is_not` (exact
    # match). `:gte`, `:lte`, `:eq`, `:not_eq` are accepted as aliases
    # of `:min`, `:max`, `:is`, `:is_not` respectively (with matching
    # `_message` overrides). Values without `#length` fail with the
    # `:nil_message` override or a default.
    module Length

      extend self

      ALIASES = {
        gte: :min,
        lte: :max,
        eq: :is,
        not_eq: :is_not,
        gte_message: :min_message,
        lte_message: :max_message,
        eq_message: :is_message,
        not_eq_message: :is_not_message
      }.freeze
      private_constant :ALIASES

      # @param value [#length, nil]
      # @param options [Hash{Symbol => Object}] see module summary
      # @option options [String] :message global failure-message override
      # @option options [String] :nil_message override when `value` lacks `#length`
      # @option options [String] :within_message, :in_message, :not_within_message,
      #   :not_in_message, :min_message, :max_message, :gt_message, :lt_message,
      #   :is_message, :is_not_message
      # @return [Validators::Failure, nil]
      # @raise [ArgumentError] when no recognized length option is given
      def call(value, options = EMPTY_HASH)
        return nil_failure(options) unless value.respond_to?(:length)

        length = value.length

        case options = options.transform_keys(ALIASES)
        in within:
          within_failure(within.begin, within.end, options) unless within.cover?(length)
        in not_within:
          not_within_failure(not_within.begin, not_within.end, options) if not_within.cover?(length)
        in in: xin
          within_failure(xin.begin, xin.end, options) unless xin.cover?(length)
        in not_in:
          not_within_failure(not_in.begin, not_in.end, options) if not_in.cover?(length)
        in min:, max:
          within_failure(min, max, options) unless length.between?(min, max)
        in min:
          min_failure(min, options) unless min <= length
        in max:
          max_failure(max, options) unless length <= max
        in gt:
          gt_failure(gt, options) unless gt < length
        in lt:
          lt_failure(lt, options) unless length < lt
        in is:
          is_failure(is, options) unless length == is
        in is_not:
          is_not_failure(is_not, options) if length == is_not
        else
          raise ArgumentError, <<~MSG.chomp
            unknown length validator options #{options.keys.inspect};
            expected one of [:within, :not_within, :in, :not_in, :min, :max, :gt, :lt, :is, :is_not] (aliases: :gte, :lte, :eq, :not_eq).
            See https://drexed.github.io/cmdx/inputs/validations/#length
          MSG
        end
      end

      private

      def nil_failure(options)
        message = options[:nil_message] || options[:message]
        Failure.new(message || I18nProxy.t("cmdx.validators.length.nil_value"))
      end

      def within_failure(min, max, options)
        message = options[:within_message] || options[:in_message] || options[:message]
        message %= { min:, max: } unless message.nil?

        Failure.new(message || I18nProxy.t("cmdx.validators.length.within", min:, max:))
      end

      def not_within_failure(min, max, options)
        message = options[:not_within_message] || options[:not_in_message] || options[:message]
        message %= { min:, max: } unless message.nil?

        Failure.new(message || I18nProxy.t("cmdx.validators.length.not_within", min:, max:))
      end

      def min_failure(min, options)
        message = options[:min_message] || options[:message]
        message %= { min: } unless message.nil?

        Failure.new(message || I18nProxy.t("cmdx.validators.length.min", min:))
      end

      def max_failure(max, options)
        message = options[:max_message] || options[:message]
        message %= { max: } unless message.nil?

        Failure.new(message || I18nProxy.t("cmdx.validators.length.max", max:))
      end

      def gt_failure(gt, options)
        message = options[:gt_message] || options[:message]
        message %= { gt: } unless message.nil?

        Failure.new(message || I18nProxy.t("cmdx.validators.length.gt", gt:))
      end

      def lt_failure(lt, options)
        message = options[:lt_message] || options[:message]
        message %= { lt: } unless message.nil?

        Failure.new(message || I18nProxy.t("cmdx.validators.length.lt", lt:))
      end

      def is_failure(is, options) # rubocop:disable Naming/PredicatePrefix
        message = options[:is_message] || options[:message]
        message %= { is: } unless message.nil?

        Failure.new(message || I18nProxy.t("cmdx.validators.length.is", is:))
      end

      def is_not_failure(is_not, options) # rubocop:disable Naming/PredicatePrefix
        message = options[:is_not_message] || options[:message]
        message %= { is_not: } unless message.nil?

        Failure.new(message || I18nProxy.t("cmdx.validators.length.is_not", is_not:))
      end

    end
  end
end
