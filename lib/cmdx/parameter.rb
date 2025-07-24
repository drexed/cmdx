# frozen_string_literal: true

module CMDx
  class Parameter

    attr_reader :name, :options, :children, :value, :errors

    def initialize(name, options = {}, &)
      # @klass = options.delete(:klass) || raise(KeyError, "klass option required")
      # @parent = options.delete(:parent)

      @name     = name
      @options  = options
      @children = []
      @errors   = Set.new

      # define_attribute(self)
      # instance_eval(&) if block_given?
    end

    def call
      tap do |parameter|
        parameter.coerce!
        parameter.validate!
        parameter.define!
      end
    end

    def required?
      !!options[:required]
    end

    def source
      @_source ||= options[:source] || parent&.signature || :context
    end

    def signature
      @_signature ||= Utils::Signature.call(source, name, options)
    end

    private

    def generate!
      # return @value if defined?(@value)

      # if source_value_required?
      #   raise ValidationError, I18n.t(
      #     "cmdx.parameters.required",
      #     default: "is a required parameter"
      #   )
      # end

      # @value = source.cmdx_try(name)
      # return @value unless @value.nil? && options.key?(:default)

      # @value = task.cmdx_yield(options[:default])
    end

    def coerce!
      # Do nothing
    end

    def validate!
      # Do nothing
    end

    def define!
      # Do nothing
    end

  end
end
