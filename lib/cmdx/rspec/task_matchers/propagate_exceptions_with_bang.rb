# frozen_string_literal: true

RSpec::Matchers.define :propagate_exceptions_with_bang do
  match do |task_class|
    # Test that call! propagates exceptions instead of handling them
    erroring_task = Class.new(task_class) do
      def call
        raise StandardError, "Test error"
      end
    end

    begin
      erroring_task.call!
      false # Should not reach here
    rescue StandardError => e
      e.message == "Test error"
    end
  end

  failure_message do |_task_class|
    "expected task to propagate exceptions with call!, but it didn't"
  end

  failure_message_when_negated do |_task_class|
    "expected task not to propagate exceptions with call!, but it did"
  end

  description do
    "propagate exceptions with call!"
  end
end
