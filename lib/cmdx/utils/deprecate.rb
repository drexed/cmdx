# frozen_string_literal: true

module CMDx
  module Utils
    module Deprecate

      extend self

      EVAL = proc do |target, callable|
        case callable
        when /error|log|warn/ then callable
        when NilClass, FalseClass, TrueClass then !!callable
        when String, Symbol then target.send(callable)
        when Proc then target.instance_exec(&callable)
        else
          raise "cannot evaluate #{callable}" unless callable.respond_to?(:call)

          callable.call(target)
        end
      end.freeze
      private_constant :EVAL

      def invoke!(task)
        type = EVAL.call(task, task.class.settings[:deprecate])

        case type
        when FalseClass # Do nothing
        when TrueClass, /error/ then raise DeprecationError, "#{task.class.name} usage prohibited"
        when /log/ then task.logger.warn { "DEPRECATED: migrate to replacement or discontinue use" }
        when /warn/ then warn("[#{task.class.name}] DEPRECATED: migrate to replacement or discontinue use", category: :deprecated)
        else raise UnknownDeprecationError, "unknown deprecation type #{type}"
        end
      end

    end
  end
end
