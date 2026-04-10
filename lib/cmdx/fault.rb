# frozen_string_literal: true

module CMDx

  # Base fault for +execute!+ when outcome matches {Definition#task_breakpoints}.
  class Fault < Error

    extend Forwardable

    # @return [ExecutionResult]
    attr_reader :result

    def_delegators :result, :task, :context, :trace

    # @param result [ExecutionResult]
    def initialize(result)
      @result = result
      super(result.reason)
    end

    # @return [Trace] v1 compatibility name
    def chain
      trace
    end

    class << self

      # @param tasks [Array<Class>]
      # @return [Class]
      def for?(*tasks)
        klass = Class.new(self) do
          def self.===(other)
            other.is_a?(superclass) && @tasks.any? { |task| other.task.is_a?(task) }
          end
        end
        klass.tap { |c| c.instance_variable_set(:@tasks, tasks) }
      end

      # @yieldparam fault [Fault]
      # @return [Class]
      def matches?(&block)
        raise ArgumentError, "block required" unless block

        blk = block
        klass = Class.new(self)
        klass.define_singleton_method(:===) do |other|
          other.is_a?(Fault) && blk.call(other)
        end
        klass
      end

    end

  end

  SkipFault = Class.new(Fault)
  FailFault = Class.new(Fault)

end
