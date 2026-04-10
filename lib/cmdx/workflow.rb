# frozen_string_literal: true

module CMDx
  # Compose tasks in ordered groups; cannot define +work+ on the host class.
  module Workflow

    def self.included(base)
      base.extend(ClassMethods)
      class << base

        def cmdx_workflow?
          true
        end

      end
    end

    module ClassMethods

      # @param tasks [Array<Class>]
      # @param options [Hash]
      # @return [void]
      def task(*tasks, **options)
        cmdx_workflow_pipeline << { tasks: tasks.flatten, options: options }
        CMDx::Task.reset_cmdx_definition!(self)
      end
      alias tasks task

      # @param method_name [Symbol]
      # @return [void]
      def method_added(method_name)
        raise "cannot redefine #{name}##{method_name}" if method_name == :work

        super
      end

    end

  end
end
