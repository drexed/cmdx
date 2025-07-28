# frozen_string_literal: true

module CMDx
  class Parameter

    attr_reader :schema, :children

    def initialize(name, options = {}, &)
      @schema   = Schema.new(name, options)
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

  end
end
