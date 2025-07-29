# frozen_string_literal: true

module CMDx
  class Parameter

    AFFIX = proc do |value, &block|
      value == true ? block.call : value
    end.freeze
    private_constant :AFFIX

    attr_accessor :task

    attr_reader :name, :options, :children, :parent, :type

    def initialize(name, options = {}, &)
      @parent   = options.delete(:parent)
      @required = options.delete(:required) || false
      @type     = Array(options.delete(:type))

      @name     = name
      @options  = options
      @children = []

      instance_eval(&) if block_given?
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

    def optional?
      !required?
    end

    def required?
      !!@required
    end

    def source
      @source ||=
        parent&.signature ||
        case value = options[:source]
        when Symbol, String then source.to_sym
        when Proc then source.call(task) # TODO: task.instance_eval(&source)
        else value || :context
        end
    end

    def signature
      @signature ||= options[:as] || begin
        prefix = AFFIX.call(options[:prefix]) { "#{source}_" }
        suffix = AFFIX.call(options[:suffix]) { "_#{source}" }

        "#{prefix}#{name}#{suffix}".strip.to_sym
      end
    end

    def define_and_verify_attribute!
      define_and_verify_attribute

      children.each do |child|
        child.task = task
        child.define_and_verify_attribute!
      end
    end

    private

    def parameter(name, **options, &)
      param = self.class.parameter(name, **options.merge(parent: self), &)
      children.push(param)
    end

    def parameters(*names, **options, &)
      params = self.class.parameters(*names, **options.merge(parent: self), &)
      children.concat(params)
    end

    def optional(*names, **options, &)
      parameters(*names, **options.merge(required: false), &)
    end

    def required(*names, **options, &)
      parameters(*names, **options.merge(required: true), &)
    end

    def define_and_verify_attribute
      raise RuntimeError, "attribute #{signature} already defined" if task.respond_to?(signature)

      param = self # HACK: creates a pointer to the parameter object within the task instance

      task.class.define_method(signature) do
        @attributes ||= {}
        @attributes[param.signature] ||= Attribute.new(param)
        @attributes[param.signature].value
      end
      task.class.send(:private, signature)
    end

  end
end
