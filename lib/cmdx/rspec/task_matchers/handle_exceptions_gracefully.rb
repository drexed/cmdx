# frozen_string_literal: true

RSpec::Matchers.define :handle_exceptions_gracefully do
  match do |task_class|
    # Test that exceptions are caught and converted to failed results
    erroring_task = Class.new(task_class) do
      def call
        raise StandardError, "Test error"
      end
    end

    task = erroring_task.new
    task.perform

    task.result.failed? &&
      task.result.metadata[:reason]&.include?("Test error") &&
      task.result.metadata[:original_exception].is_a?(StandardError)
  end

  failure_message do |_task_class|
    "expected task to handle exceptions gracefully by converting to failed results, but it didn't"
  end

  failure_message_when_negated do |_task_class|
    "expected task not to handle exceptions gracefully, but it did"
  end

  description do
    "handle exceptions gracefully"
  end
end
