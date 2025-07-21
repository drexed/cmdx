# frozen_string_literal: true

module CMDx
  class Task

    Utils::Setting.call(self, :settings, default: -> { CMDx.configuration.to_hash.merge(tags: []) })
    Utils::Setting.call(self, :middlewares, default: -> { settings[:middlewares] })
    Utils::Setting.call(self, :callbacks, default: -> { settings[:callbacks] })
    Utils::Setting.call(self, :parameters, default: -> { Parameters::Registry.new })

    attr_reader :context, :errors

    def initialize(context = {})
      @context = context
      @errors  = Errors.new
    end

    class << self

      def parameter(name, options = {})
        @parameter = Parameters::Attribute.new(name, options)
      end

    end

  end
end
