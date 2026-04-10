# frozen_string_literal: true

module CMDx
  # Module-level registry of attribute validators. Each validator checks a value
  # against options, raising ValidationError on failure.
  module Validators

    @registry = {}

    class << self

      # @return [Hash<Symbol, Proc>]
      attr_reader :registry

      # Register a custom validator.
      #
      # @param name [Symbol]
      # @param callable [Proc, #call]
      # @return [void]
      def register(name, callable)
        @registry[name.to_sym] = Callable.wrap(callable)
      end

      # @param name [Symbol]
      # @return [void]
      def deregister(name)
        @registry.delete(name.to_sym)
      end

      # Run a named validator.
      #
      # @param name [Symbol] the validator name
      # @param value [Object] the value to validate
      # @param options [Hash, true] validator options
      # @param task [Object] the task instance (for condition evaluation)
      # @param task_registry [Hash, nil] per-task validator overrides
      # @return [String, nil] error message or nil if valid
      def validate(name, value, options, task: nil, task_registry: nil)
        validator = (task_registry && task_registry[name]) || @registry[name]
        return nil unless validator

        opts = options.is_a?(Hash) ? options : {}

        return nil if opts[:allow_nil] && value.nil?

        return nil if opts.key?(:if) && !Callable.evaluate(opts[:if], task || value)

        return nil if opts.key?(:unless) && Callable.evaluate(opts[:unless], task || value)

        begin
          validator.call(value, opts)
          nil
        rescue ValidationError => e
          opts[:message] || e.message
        end
      end

    end

    # -- Built-in validators --

    register(:presence, lambda { |value, _options = {}|
      blank = value.nil? || (value.respond_to?(:empty?) && value.empty?) ||
              (value.is_a?(String) && value.strip.empty?)
      raise ValidationError, Messages.resolve("validation.presence") if blank
    })

    register(:absence, lambda { |value, _options = {}|
      present = !value.nil? && !(value.respond_to?(:empty?) && value.empty?) &&
                !(value.is_a?(String) && value.strip.empty?)
      raise ValidationError, Messages.resolve("validation.absence") if present
    })

    register(:format, lambda { |value, options = {}|
      return if value.nil?

      pattern = options.is_a?(Regexp) ? options : (options[:with] || options[:regexp])
      anti_pattern = options.is_a?(Hash) ? options[:without] : nil

      raise ValidationError, Messages.resolve("validation.format") if pattern && !value.to_s.match?(pattern)

      raise ValidationError, Messages.resolve("validation.format") if anti_pattern && value.to_s.match?(anti_pattern)
    })

    register(:inclusion, lambda { |value, options = {}|
      return if value.nil?

      collection = options[:in] || options[:within]
      return unless collection

      unless collection.include?(value)
        if collection.is_a?(Range)
          raise ValidationError,
                options[:within_message] || options[:in_message] ||
                Messages.resolve("validation.inclusion.within", range: collection)
        else
          raise ValidationError,
                options[:of_message] || Messages.resolve("validation.inclusion.in")
        end
      end
    })

    register(:exclusion, lambda { |value, options = {}|
      return if value.nil?

      collection = options[:in] || options[:within]
      return unless collection

      if collection.include?(value)
        if collection.is_a?(Range)
          raise ValidationError,
                options[:within_message] || options[:in_message] ||
                Messages.resolve("validation.exclusion.within", range: collection)
        else
          raise ValidationError,
                options[:of_message] || Messages.resolve("validation.exclusion.in")
        end
      end
    })

    register(:length, lambda { |value, options = {}|
      return if value.nil?
      return unless value.respond_to?(:length)

      len = value.length

      range = options[:within] || options[:in]
      if range && !range.include?(len)
        raise ValidationError,
              options[:within_message] || options[:in_message] ||
              Messages.resolve("validation.length.within", range: range)
      end

      not_range = options[:not_within] || options[:not_in]
      if not_range && not_range.include?(len)
        raise ValidationError,
              options[:not_within_message] || options[:not_in_message] ||
              Messages.resolve("validation.length.not_within", range: not_range)
      end

      if options[:min] && len < options[:min]
        raise ValidationError,
              options[:min_message] || Messages.resolve("validation.length.min", count: options[:min])
      end

      if options[:max] && len > options[:max]
        raise ValidationError,
              options[:max_message] || Messages.resolve("validation.length.max", count: options[:max])
      end

      if options[:is] && len != options[:is]
        raise ValidationError,
              options[:is_message] || Messages.resolve("validation.length.is", count: options[:is])
      end

      if options[:is_not] && len == options[:is_not]
        raise ValidationError,
              options[:is_not_message] || Messages.resolve("validation.length.is_not", count: options[:is_not])
      end
    })

    register(:numeric, lambda { |value, options = {}|
      return if value.nil?

      num = begin
        value.is_a?(Numeric) ? value : Float(value)
      rescue StandardError
        nil
      end
      return unless num

      range = options[:within] || options[:in]
      if range && !range.include?(num)
        raise ValidationError,
              options[:within_message] || Messages.resolve("validation.numeric.within", range: range)
      end

      not_range = options[:not_within] || options[:not_in]
      if not_range && not_range.include?(num)
        raise ValidationError,
              options[:not_within_message] || Messages.resolve("validation.numeric.not_within", range: not_range)
      end

      if options[:min] && num < options[:min]
        raise ValidationError,
              options[:min_message] || Messages.resolve("validation.numeric.min", count: options[:min])
      end

      if options[:max] && num > options[:max]
        raise ValidationError,
              options[:max_message] || Messages.resolve("validation.numeric.max", count: options[:max])
      end

      if options[:is] && num != options[:is]
        raise ValidationError,
              options[:is_message] || Messages.resolve("validation.numeric.is", count: options[:is])
      end

      if options[:is_not] && num == options[:is_not]
        raise ValidationError,
              options[:is_not_message] || Messages.resolve("validation.numeric.is_not", count: options[:is_not])
      end
    })

  end
end
