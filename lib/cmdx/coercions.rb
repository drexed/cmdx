# frozen_string_literal: true

module CMDx
  # Module-level registry of type coercions. Each coercion converts a value
  # to a target type, raising CoercionError on failure.
  module Coercions

    BOOLEAN_TRUE  = %w[true yes on 1 t y].freeze
    BOOLEAN_FALSE = %w[false no off 0 f n].freeze

    @registry = {}

    class << self

      # @return [Hash<Symbol, Proc>]
      attr_reader :registry

      # Register a custom coercion.
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

      # Coerce a value to the given type(s).
      #
      # @param types [Symbol, Array<Symbol>] one or more type names
      # @param value [Object] the value to coerce
      # @param options [Hash] coercion options (e.g., strptime, precision)
      # @param task_registry [Hash, nil] per-task coercion overrides
      # @return [Object] the coerced value
      # @raise [CMDx::CoercionError] if coercion fails
      def coerce(types, value, options = {}, task_registry: nil)
        type_list = Array(types)
        return value if value.nil?

        type_list.each do |type|
          coercer = (task_registry && task_registry[type]) || @registry[type]
          raise CoercionError, "Unknown coercion type: #{type}" unless coercer

          begin
            return coercer.call(value, options)
          rescue CoercionError
            next
          end
        end

        raise CoercionError, Messages.resolve("coercion.single", type: type_list.first) if type_list.size == 1

        raise CoercionError, Messages.resolve("coercion.multi", types: type_list.join(", "))
      end

    end

    # -- Built-in coercions --

    register(:array, lambda { |value, _options|
      case value
      when Array then value
      when String
        begin
          parsed = JSON.parse(value)
          parsed.is_a?(Array) ? parsed : [parsed]
        rescue JSON::ParserError
          [value]
        end
      else [value]
      end
    })

    register(:big_decimal, lambda { |value, options|
      begin
        result = BigDecimal(value.to_s)
        result = result.round(options[:precision]) if options&.dig(:precision)
        result
      rescue ArgumentError, TypeError
        raise CoercionError, Messages.resolve("coercion.single", type: :big_decimal)
      end
    })

    register(:boolean, lambda { |value, _options|
      str = value.to_s.downcase.strip
      return true if BOOLEAN_TRUE.include?(str)
      return false if BOOLEAN_FALSE.include?(str)

      raise CoercionError, Messages.resolve("coercion.single", type: :boolean)
    })

    register(:complex, lambda { |value, _options|
      begin
        Complex(value)
      rescue ArgumentError, TypeError
        raise CoercionError, Messages.resolve("coercion.single", type: :complex)
      end
    })

    register(:date, lambda { |value, options|
      begin
        if options&.dig(:strptime)
          Date.strptime(value.to_s, options[:strptime])
        else
          value.is_a?(Date) ? value : Date.parse(value.to_s)
        end
      rescue ArgumentError, TypeError
        raise CoercionError, Messages.resolve("coercion.single", type: :date)
      end
    })

    register(:datetime, lambda { |value, options|
      begin
        if options&.dig(:strptime)
          DateTime.strptime(value.to_s, options[:strptime])
        else
          value.is_a?(DateTime) ? value : DateTime.parse(value.to_s)
        end
      rescue ArgumentError, TypeError
        raise CoercionError, Messages.resolve("coercion.single", type: :datetime)
      end
    })

    register(:float, lambda { |value, _options|
      begin
        Float(value)
      rescue ArgumentError, TypeError
        raise CoercionError, Messages.resolve("coercion.single", type: :float)
      end
    })

    register(:hash, lambda { |value, _options|
      case value
      when Hash then value
      when String
        begin
          parsed = JSON.parse(value)
          parsed.is_a?(Hash) ? parsed : raise(CoercionError, Messages.resolve("coercion.single", type: :hash))
        rescue JSON::ParserError
          raise CoercionError, Messages.resolve("coercion.single", type: :hash)
        end
      else
        raise CoercionError, Messages.resolve("coercion.single", type: :hash) unless value.respond_to?(:to_h)

        value.to_h

      end
    })

    register(:integer, lambda { |value, _options|
      begin
        Integer(value)
      rescue ArgumentError, TypeError
        raise CoercionError, Messages.resolve("coercion.single", type: :integer)
      end
    })

    register(:rational, lambda { |value, _options|
      begin
        Rational(value)
      rescue ArgumentError, TypeError, ZeroDivisionError
        raise CoercionError, Messages.resolve("coercion.single", type: :rational)
      end
    })

    register(:string, lambda { |value, _options|
      value.to_s
    })

    register(:symbol, lambda { |value, _options|
      begin
        value.to_s.to_sym
      rescue NoMethodError
        raise CoercionError, Messages.resolve("coercion.single", type: :symbol)
      end
    })

    register(:time, lambda { |value, options|
      begin
        if options&.dig(:strptime)
          Time.strptime(value.to_s, options[:strptime])
        else
          value.is_a?(Time) ? value : Time.parse(value.to_s)
        end
      rescue ArgumentError, TypeError
        raise CoercionError, Messages.resolve("coercion.single", type: :time)
      end
    })

  end
end
