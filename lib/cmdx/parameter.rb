# frozen_string_literal: true

module CMDx
  class Parameter

    attr_accessor :task

    attr_reader :klass, :parent, :type, :name, :options, :children

    def initialize(name, options = {}, &block)
      @klass     = options.delete(:klass) || raise(KeyError, "klass option required")
      @parent    = options.delete(:parent)
      @required  = options.delete(:required) || false
      @type      = Array(options.delete(:type))

      @name      = name
      @options   = options
      @block     = block if block_given?
      @children  = []
    end

    class << self

      def parameter(name, ...)
        new(name, ...)
      end

      def parameters(*names, **options, &)
        if names.none?
          raise ArgumentError, "no parameters given"
        elsif (names.size > 1) && options.key?(:as)
          raise ArgumentError, ":as option only supports one parameter per definition"
        end

        names.filter_map { |name| parameter(name, **options, &) }
      end

      def optional(*names, **options, &)
        parameters(*names, **options.merge(required: false), &)
      end

      def required(*names, **options, &)
        parameters(*names, **options.merge(required: true), &)
      end

    end

    def parameter(name, **options, &)
      param = self.class.parameter(name, **options.merge(klass:, parent: self), &)
      children.push(param)
    end

    def parameters(*names, **options, &)
      params = self.class.parameters(*names, **options.merge(klass:, parent: self), &)
      children.concat(params)
    end

    def optional(*names, **options, &)
      parameters(*names, **options.merge(required: false), &)
    end

    def required(*names, **options, &)
      parameters(*names, **options.merge(required: true), &)
    end

    def optional?
      !@required
    end

    def required?
      !optional?
    end

    def source
      @source ||= options[:source]&.to_sym || parent&.signature || :context
    end

    def signature
      @signature ||= Utils::Signature.derive!(source, name, options)
    end

    def process!
      attribute!
      instance_eval(&@block) unless @block.nil?
      children.each(&:process!)
    end

    def value
      return @value if defined?(@value)

      raise RuntimeError, "a Task or Workflow is required" unless task.is_a?(Task)

      @value ||= ParameterValue.new(task, self)
    end

    def to_h
      ParameterTransformer.to_h(self)
    end

    def to_s
      ParameterTransformer.to_s(to_h)
    end

    private

    def attribute!
      param = self

      klass.define_method(signature) do
        param.task = self
        param.value.derived
      end

      klass.send(:private, signature)
    end

  end
end
