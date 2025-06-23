# frozen_string_literal: true

module TaskBuilderHelpers

  module_function

  def build_task(&block)
    Class.new(SimulationTask) do
      instance_eval(&block) if block_given?

      def self.name
        "TestTask"
      end
    end
  end

  def build_batch(&block)
    Class.new(SimulationBatch) do
      instance_eval(&block) if block_given?

      def self.name
        "TestBatch"
      end
    end
  end

  def build_parameter_task(&block)
    Class.new(SimulationTask) do
      instance_eval(&block) if block_given?

      def self.name
        "ParameterTestTask"
      end

      def call
        # Default implementation for parameter testing
      end
    end
  end

end
