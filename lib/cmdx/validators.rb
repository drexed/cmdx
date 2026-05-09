# frozen_string_literal: true

module CMDx
  # Registry of named validators applied to resolved input/output values.
  # Ships with built-ins for `:absence`, `:exclusion`, `:format`,
  # `:inclusion`, `:length`, `:numeric`, `:presence`. Validators return a
  # {Failure} on invalid input (recorded on `task.errors`) or `nil` on
  # success. The `:validate` key supports inline callables.
  class Validators

    # Sentinel returned by a validator to signal invalid input. Runtime
    # records its `message` on the task's errors.
    Failure = Data.define(:message)

    attr_reader :registry

    def initialize
      @registry = {
        absence: Validators::Absence,
        exclusion: Validators::Exclusion,
        format: Validators::Format,
        inclusion: Validators::Inclusion,
        length: Validators::Length,
        numeric: Validators::Numeric,
        presence: Validators::Presence
      }
    end

    # @param source [Validators] registry to duplicate
    # @return [void]
    def initialize_copy(source)
      @registry = source.registry.dup
    end

    # Registers a named validator, overwriting any existing entry.
    #
    # @param name [Symbol]
    # @param callable [#call, nil] pass either this or a block
    # @param block [#call, nil] validator callable when `callable` is omitted
    # @yield validator body — `call(value, options = {})`
    # @return [Validators] self for chaining
    # @raise [ArgumentError] when both `callable` and a block are given, or
    #   when the resolved validator isn't callable
    def register(name, callable = nil, &block)
      validator = callable || block

      if callable && block
        raise ArgumentError, "provide either a callable or a block, not both"
      elsif !validator.respond_to?(:call)
        raise ArgumentError, "validator must respond to #call"
      end

      registry[name.to_sym] = validator
      self
    end

    # @param name [Symbol]
    # @return [Validators] self for chaining
    def deregister(name)
      registry.delete(name.to_sym)
      self
    end

    # @param name [Symbol]
    # @return [#call]
    # @raise [UnknownEntryError] when `name` isn't registered
    def lookup(name)
      registry[name] || begin
        raise UnknownEntryError, "unknown validator: #{name}"
      end
    end

    # Picks registered-validator keys out of a declaration's options and
    # appends `:validate` (inline callable(s)) when present.
    #
    # @param options [Hash{Symbol => Object}] declaration options
    # @option options [Object] :presence payload for the presence validator (`call`)
    # @option options [Object] :absence payload for the absence validator (`call`)
    # @option options [Object] :format payload for the format validator (`call`)
    # @option options [Object] :inclusion payload for the inclusion validator (`call`)
    # @option options [Object] :exclusion payload for the exclusion validator (`call`)
    # @option options [Object] :length payload for the length validator (`call`)
    # @option options [Object] :numeric payload for the numeric validator (`call`)
    # @option options [Object, Array<Object>] :validate inline callable(s) (`Validators::Validate`)
    # @return [Hash{Symbol => Object}] validator rules to run
    def extract(options)
      return EMPTY_HASH if options.empty?

      rules = options.slice(*registry.keys)
      rules = rules.merge(validate: options[:validate]) if options.key?(:validate)
      rules
    end

    # @return [Boolean]
    def empty?
      registry.empty?
    end

    # @return [Integer]
    def size
      registry.size
    end

    # Runs every rule against `value`, recording a failure message on
    # `task.errors` under `name` for each failure. Respects `:allow_nil`
    # and `:if`/`:unless` per-rule.
    #
    # @param task [Task]
    # @param name [Symbol] attribute name for error reporting
    # @param value [Object] value being validated
    # @param rules [Hash{Symbol => Object}] from {#extract}
    # @return [void]
    def validate(task, name, value, rules)
      return if rules.empty?

      rules.each do |type, raw_options|
        if type == :validate
          Array(raw_options).each do |handler|
            result = Validators::Validate.call(task, value, handler)
            task.errors.add(name, result.message) if result.is_a?(Failure)
          end
          next
        end

        options = normalize_options(raw_options)
        next if options.nil?

        next if options[:allow_nil] && value.nil?
        next unless Util.satisfied?(options[:if], options[:unless], task, value)

        result = lookup(type).call(value, options)
        next unless result.is_a?(Failure)

        task.errors.add(name, result.message)
      end
    end

    private

    # @param raw_options [Object] truthy flag, Hash, Array, Regexp, etc. from a declaration
    # @return [Hash{Symbol => Object}, nil] normalized rule options, or nil when disabled
    # @raise [ArgumentError] when `raw_options` has an unsupported shape
    def normalize_options(raw_options)
      case raw_options
      when FalseClass, NilClass
        nil
      when TrueClass
        EMPTY_HASH
      when Hash
        raw_options
      when Array
        { in: raw_options }
      when Regexp
        { with: raw_options }
      else
        raise ArgumentError, "unsupported validator option format: #{raw_options.inspect}"
      end
    end

  end
end
