# frozen_string_literal: true

module CMDx

  class Fault < Error

    attr_reader :result

    def initialize(result)
      @result = result
      # TODO: make reason a method on the result object
      super(result.metadata[:reason] || Utils::Locale.t("cmdx.faults.unspecified"))
    end

    class << self

      def build(result)
        raise "cannot build a #{Result::SUCCESS} fault" if result.success?

        klass = CMDx.const_get(result.status.capitalize)
        klass.new(result)
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

  # Fault raised when a task is intentionally skipped during execution.
  #
  # This fault occurs when a task determines it should not execute based on
  # its current context or conditions. Skipped tasks are not considered failures
  # but rather intentional bypasses of task execution logic.
  #
  # @example Task that skips based on conditions
  #   class ProcessPaymentTask < CMDx::Task
  #     def call
  #       skip!(reason: "Payment already processed") if payment_exists?
  #     end
  #   end
  #
  #   result = ProcessPaymentTask.call(payment_id: 123)
  #   # raises CMDx::Skipped when payment already exists
  #
  # @example Catching skipped faults
  #   begin
  #     MyTask.call!(data: "invalid")
  #   rescue CMDx::Skipped => e
  #     puts "Task was skipped: #{e.message}"
  #   end
  Skipped = Class.new(Fault)

  # Fault raised when a task execution fails due to errors or validation failures.
  #
  # This fault occurs when a task encounters an error condition, validation failure,
  # or any other condition that prevents successful completion. Failed tasks indicate
  # that the intended operation could not be completed successfully.
  #
  # @example Task that fails due to validation
  #   class ValidateUserTask < CMDx::Task
  #     required :email, type: :string
  #
  #     def call
  #       fail!(reason: "Invalid email format") unless valid_email?
  #     end
  #   end
  #
  #   result = ValidateUserTask.call(email: "invalid-email")
  #   # raises CMDx::Failed when email is invalid
  #
  # @example Catching failed faults
  #   begin
  #     RiskyTask.call!(data: "problematic")
  #   rescue CMDx::Failed => e
  #     puts "Task failed: #{e.message}"
  #     puts "Original task: #{e.task.class.name}"
  #   end
  Failed = Class.new(Fault)

end
