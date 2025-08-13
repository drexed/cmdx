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
      @parent = options.delete(:parent)
      @required = options.delete(:required) || false
      @types = Array(options.delete(:types) || options.delete(:type))

      @name = name.to_sym
      @options = options
      @children = []

      instance_eval(&) if block_given?
    end

    class << self

      # TODO: simplify this by only having a defines method and removing the define method
      # TODO: rename defines to build

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

    def required?
      !!@required
    end

    def source
      @source ||= parent&.method_name || begin
        value = options[:source]

        if value.is_a?(Proc)
          task.instance_eval(&value)
        elsif value.respond_to?(:call)
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

        :"#{prefix}#{name}#{suffix}"
      end
    end

    def define_and_verify_tree
      define_and_verify

      children.each do |child|
        child.task = task
        child.define_and_verify_tree
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

      attribute_value = AttributeValue.new(self)
      attribute_value.generate
      attribute_value.validate

      task.instance_eval(<<~RUBY, __FILE__, __LINE__ + 1)
        def #{method_name}
          attributes[:#{method_name}]
        end
      RUBY
    end

  end
end
