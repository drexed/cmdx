# frozen_string_literal: true

module CMDx
  class Validators
    # Validates a numeric `value` against one of: `:within` / `:not_within`
    # / `:in` / `:not_in` (Range), `:min` + `:max`, `:gt` / `:lt` (strict
    # comparison), or `:is` / `:is_not` (exact match). `:gte`, `:lte`,
    # `:eq`, `:not_eq` are accepted as aliases of `:min`, `:max`, `:is`,
    # `:is_not` respectively (with matching `_message` overrides). `nil`
    # fails with `:nil_message` override or default.
    module Numeric

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

      # @param value [Numeric, nil]
      # @param options [Hash{Symbol => Object}] see module summary
      # @option options [String] :message global failure-message override
      # @option options [String] :nil_message override when `value` is nil
      # @option options [String] :within_message, :in_message, :not_within_message,
      #   :not_in_message, :min_message, :max_message, :gt_message, :lt_message,
      #   :is_message, :is_not_message
      # @return [Validators::Failure, nil]
      # @raise [ArgumentError] when no recognized numeric option is given
      def call(value, options = EMPTY_HASH)
        return nil_failure(options) if value.nil?

        case options = options.transform_keys(ALIASES)
        in within:
          within_failure(within.begin, within.end, options) unless within.cover?(value)
        in not_within:
          not_within_failure(not_within.begin, not_within.end, options) if not_within.cover?(value)
        in in: xin
          within_failure(xin.begin, xin.end, options) unless xin.cover?(value)
        in not_in:
          not_within_failure(not_in.begin, not_in.end, options) if not_in.cover?(value)
        in min:, max:
          within_failure(min, max, options) unless value.between?(min, max)
        in min:
          min_failure(min, options) unless min <= value
        in max:
          max_failure(max, options) unless value <= max
        in gt:
          gt_failure(gt, options) unless gt < value
        in lt:
          lt_failure(lt, options) unless value < lt
        in is:
          is_failure(is, options) unless value == is
        in is_not:
          is_not_failure(is_not, options) if value == is_not
        else
          raise ArgumentError, "unknown numeric validator options given"
        end
      end

      private

      def nil_failure(options)
        message = options[:nil_message] || options[:message]
        Failure.new(message || I18nProxy.t("cmdx.validators.numeric.nil_value"))
      end

      def within_failure(min, max, options)
        message = options[:within_message] || options[:in_message] || options[:message]
        message %= { min:, max: } unless message.nil?

        Failure.new(message || I18nProxy.t("cmdx.validators.numeric.within", min:, max:))
      end

      def not_within_failure(min, max, options)
        message = options[:not_within_message] || options[:not_in_message] || options[:message]
        message %= { min:, max: } unless message.nil?

        Failure.new(message || I18nProxy.t("cmdx.validators.numeric.not_within", min:, max:))
      end

      def min_failure(min, options)
        message = options[:min_message] || options[:message]
        message %= { min: } unless message.nil?

        Failure.new(message || I18nProxy.t("cmdx.validators.numeric.min", min:))
      end

      def max_failure(max, options)
        message = options[:max_message] || options[:message]
        message %= { max: } unless message.nil?

        Failure.new(message || I18nProxy.t("cmdx.validators.numeric.max", max:))
      end

      def gt_failure(gt, options)
        message = options[:gt_message] || options[:message]
        message %= { gt: } unless message.nil?

        Failure.new(message || I18nProxy.t("cmdx.validators.numeric.gt", gt:))
      end

      def lt_failure(lt, options)
        message = options[:lt_message] || options[:message]
        message %= { lt: } unless message.nil?

        Failure.new(message || I18nProxy.t("cmdx.validators.numeric.lt", lt:))
      end

      def is_failure(is, options) # rubocop:disable Naming/PredicatePrefix
        message = options[:is_message] || options[:message]
        message %= { is: } unless message.nil?

        Failure.new(message || I18nProxy.t("cmdx.validators.numeric.is", is:))
      end

      def is_not_failure(is_not, options) # rubocop:disable Naming/PredicatePrefix
        message = options[:is_not_message] || options[:message]
        message %= { is_not: } unless message.nil?

        Failure.new(message || I18nProxy.t("cmdx.validators.numeric.is_not", is_not:))
      end

    end
  end
end
