# frozen_string_literal: true

module CMDx
  class Attribute

    AFFIX = proc do |value, &block|
      value == true ? block.call : value
    end.freeze
    private_constant :AFFIX

    attr_accessor :task

    attr_reader :name, :options, :children, :parent, :types

    def initialize(name, options = {}, &)
      @parent   = options.delete(:parent)
      @required = options.delete(:required) || false
      @types    = Array(options.delete(:types) || options.delete(:type))

      @name     = name
      @options  = options
      @children = []

      instance_eval(&) if block_given?
    end

    class << self

      def define(name, ...)
        new(name, ...)
      end

      def defines(*names, **options, &)
        if names.none?
          raise ArgumentError, "no attributes given"
        elsif (names.size > 1) && options.key?(:as)
          raise ArgumentError, ":as option only supports one attribute per definition"
        end

        names.filter_map { |name| define(name, **options, &) }
      end

      def optional(*names, **options, &)
        defines(*names, **options.merge(required: false), &)
      end

      def required(*names, **options, &)
        defines(*names, **options.merge(required: true), &)
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
        parent&.method_name ||
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

    def method_name
      @method_name ||= options[:as] || begin
        prefix = AFFIX.call(options[:prefix]) { "#{source}_" }
        suffix = AFFIX.call(options[:suffix]) { "_#{source}" }

        "#{prefix}#{name}#{suffix}".strip.to_sym
      end
    end

    def define_and_verify!
      define_and_verify

      children.each do |child|
        child.task = task
        child.define_and_verify!
      end
    end

    private

    def attribute(name, **options, &)
      attr = self.class.define(name, **options.merge(parent: self), &)
      children.push(attr)
    end

    def attributes(*names, **options, &)
      attrs = self.class.defines(*names, **options.merge(parent: self), &)
      children.concat(attrs)
    end

    def optional(*names, **options, &)
      attributes(*names, **options.merge(required: false), &)
    end

    def required(*names, **options, &)
      attributes(*names, **options.merge(required: true), &)
    end

    def define_and_verify
      raise "#{task.class.name}##{method_name} already defined" if task.respond_to?(method_name, true)

      v = AttributeValue.value(self)
      task.class.define_method(method_name) { v }
      task.class.send(:private, method_name)
    end

  end
end
