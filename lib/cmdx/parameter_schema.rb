# frozen_string_literal: true

module CMDx
  class ParameterSchema

    AFFIX = proc do |value, &block|
      value == true ? block.call : value
    end.freeze

    attr_accessor :task

    attr_reader :name, :options, :parent, :required, :type

    def initialize(name, options = {})
      @parent   = options.delete(:parent)
      @required = options.delete(:required) || false
      @type     = Array(options.delete(:type))
      @name     = name
      @options  = options
    end

    def optional?
      !required?
    end

    def required?
      !!required
    end

    def source
      @source ||=
        case source = options[:source]
        when Symbol, String then source.to_sym
        when Proc then source.call(task) # || task.instance_eval(&source) TODO:
        else source || parent&.signature || :context
        end
    end

    def signature
      @signature ||= options[:as] || begin
        prefix = AFFIX.call(options[:prefix]) { "#{source}_" }
        suffix = AFFIX.call(options[:suffix]) { "_#{source}" }

        "#{prefix}#{name}#{suffix}".strip.to_sym
      end
    end

  end
end
