# frozen_string_literal: true

module CMDx
  class Parameter

    attr_reader :klass, :name, :options, :children

    def initialize(name, options = {}, &block)
      @klass     = options.delete(:klass) || raise(KeyError, "klass option required")
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

    def call
      ParameterAttribute.call(self)
      instance_eval(&@block) unless @block.nil?
      # TODO: freeze once called
    end

    def parameter(name, **options, &)
      param = self.class.parameter(name, **options.merge(klass:, parent: self), &)
      children.concat(param)
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
      !options[:required]
    end

    def required?
      !optional?
    end

    def source
      @source ||= options[:source]&.to_sym || options[:parent]&.signature || :context
    end

    def signature
      @signature ||= Utils::Signature.call(source, name, options)
    end

    # def to_h
    #   ParameterSerializer.call(self)
    # end

    # def to_s
    #   ParameterInspector.call(to_h)
    # end

  end
end
