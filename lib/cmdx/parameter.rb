# frozen_string_literal: true

module CMDx
  class Parameter

    __cmdx_attr_delegator :invalid?, :valid?, to: :errors

    attr_accessor :task
    attr_reader :klass, :parent, :name, :type, :options, :children, :errors

    def initialize(name, **options, &)
      @klass    = options.delete(:klass) || raise(KeyError, "klass option required")
      @parent   = options.delete(:parent)
      @type     = options.delete(:type) || :virtual
      @required = options.delete(:required) || false

      @name     = name
      @options  = options
      @children = []
      @errors   = Errors.new

      define_attribute(self)
      instance_eval(&) if block_given?
    end

    class << self

      def optional(*names, **options, &)
        if names.none?
          raise ArgumentError, "no parameters given"
        elsif !names.one? && options.key?(:as)
          raise ArgumentError, ":as option only supports one parameter per definition"
        end

        names.filter_map { |n| new(n, **options, &) }
      end

      def required(*names, **options, &)
        optional(*names, **options.merge(required: true), &)
      end

    end

    def optional(*names, **options, &)
      parameters = Parameter.optional(*names, **options.merge(klass: @klass, parent: self), &)
      children.concat(parameters)
    end

    def required(*names, **options, &)
      parameters = Parameter.required(*names, **options.merge(klass: @klass, parent: self), &)
      children.concat(parameters)
    end

    def required?
      !!@required
    end

    def optional?
      !required?
    end

    def method_name
      @method_name ||= Utils::NameFormatter.call(name, method_source, options)
    end

    def method_source
      @method_source ||= options[:source] || parent&.method_name || :context
    end

    def to_h
      ParameterSerializer.call(self)
    end

    def to_s
      ParameterInspector.call(to_h)
    end

    private

    def define_attribute(parameter)
      klass.send(:define_method, parameter.method_name) do
        @parameters_cache ||= {}
        return @parameters_cache[parameter.method_name] if @parameters_cache.key?(parameter.method_name)

        begin
          parameter_value = ParameterValue.new(self, parameter).call
        rescue CoercionError, ValidationError => e
          parameter.errors.add(parameter.method_name, e.message)
          errors.merge!(parameter.errors.to_hash)
        ensure
          @parameters_cache[parameter.method_name] = parameter_value
        end

        @parameters_cache[parameter.method_name]
      end

      klass.send(:private, parameter.method_name)
    end

  end
end
