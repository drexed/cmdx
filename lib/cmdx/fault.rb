# frozen_string_literal: true

module CMDx
  class Fault < Error

    cmdx_attr_delegator :task, :chain, :context,
                        to: :result

    def initialize(result)
      @result = result
      super(result.metadata[:reason] || I18n.t("cmdx.faults.unspecified", default: "no reason given"))
    end

    class << self

      def build(result)
        fault = CMDx.const_get(result.status.capitalize)
        fault.new(result)
      end

      def for?(*tasks)
        temp_fault = Class.new(self) do
          def self.===(other)
            other.is_a?(superclass) && @tasks.any? { |task| other.task.is_a?(task) }
          end
        end

        temp_fault.tap { |c| c.instance_variable_set(:@tasks, tasks) }
      end

      def matches?(&block)
        raise ArgumentError, "block required" unless block_given?

        temp_fault = Class.new(self) do
          def self.===(other)
            other.is_a?(superclass) && @block.call(other)
          end
        end

        temp_fault.tap { |c| c.instance_variable_set(:@block, block) }
      end

    end

  end
end
