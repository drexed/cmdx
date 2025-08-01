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
      @parent = options.delete(:parent)
      @required = options.delete(:required) || false
      @type = Array(options.delete(:type))

      @name = name
      @options = options
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
        when Symbol, String then value.to_sym
        when Proc then task.instance_eval(&value)
        else
          if value.respond_to?(:call)
            value.call(task)
          else
            value || :context
          end
        end
    end

    def signature
      @signature ||= options[:as] || begin
        prefix = AFFIX.call(options[:prefix]) { "#{source}_" }
        suffix = AFFIX.call(options[:suffix]) { "_#{source}" }

        "#{prefix}#{name}#{suffix}".strip.to_sym
      end
    end

    def attribute
      task.attributes[signature] ||= Attribute.new(self)
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
      raise "attribute #{signature} already defined" if task.respond_to?(signature)

      value = attribute.value # HACK: hydrate and verify the attribute value
      task.class.define_method(signature) { value }
      task.class.send(:private, signature)
    end

  end
end
