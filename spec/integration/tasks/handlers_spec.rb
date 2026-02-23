# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task handlers", type: :feature do
  context "when using status-based handlers" do
    it "executes on_success handler" do
      task = create_successful_task

      result = task.execute
      handled = []

      result.on(:success) { handled << :on_success }

      expect(handled).to eq([:on_success])
    end

    it "executes on_failed handler" do
      task = create_failing_task(reason: "Test failure")

      result = task.execute
      handled = []

      result.on(:failed) { handled << :on_failed }

      expect(handled).to eq([:on_failed])
    end

    it "executes on_skipped handler" do
      task = create_skipping_task(reason: "Test skip")

      result = task.execute
      handled = []

      result.on(:skipped) { handled << :on_skipped }

      expect(handled).to eq([:on_skipped])
    end

    it "only executes the matching handler" do
      success_task = create_successful_task
      failed_task = create_failing_task

      success_result = success_task.execute
      failed_result = failed_task.execute

      success_handled = []
      failed_handled = []

      success_result
        .on(:success) { success_handled << :success }
        .on(:failed) { success_handled << :failed }
        .on(:skipped) { success_handled << :skipped }

      failed_result
        .on(:success) { failed_handled << :success }
        .on(:failed) { failed_handled << :failed }
        .on(:skipped) { failed_handled << :skipped }

      expect(success_handled).to eq([:success])
      expect(failed_handled).to eq([:failed])
    end
  end

  context "when using state-based handlers" do
    it "executes on_complete handler" do
      task = create_successful_task

      result = task.execute
      handled = []

      result.on(:complete) { handled << :on_complete }

      expect(handled).to eq([:on_complete])
    end

    it "executes on_interrupted handler" do
      task = create_failing_task

      result = task.execute
      handled = []

      result.on(:interrupted) { handled << :on_interrupted }

      expect(handled).to eq([:on_interrupted])
    end

    it "only executes the matching state handler" do
      complete_task = create_successful_task
      interrupted_task = create_failing_task

      complete_result = complete_task.execute
      interrupted_result = interrupted_task.execute

      complete_handled = []
      interrupted_handled = []

      complete_result
        .on(:complete) { complete_handled << :complete }
        .on(:interrupted) { complete_handled << :interrupted }

      interrupted_result
        .on(:complete) { interrupted_handled << :complete }
        .on(:interrupted) { interrupted_handled << :interrupted }

      expect(complete_handled).to eq([:complete])
      expect(interrupted_handled).to eq([:interrupted])
    end
  end

  context "when using outcome-based handlers" do
    it "executes on_good for success" do
      task = create_successful_task

      result = task.execute
      handled = []

      result.on(:good) { handled << :on_good }

      expect(handled).to eq([:on_good])
    end

    it "executes on_good for skipped" do
      task = create_skipping_task

      result = task.execute
      handled = []

      result.on(:good) { handled << :on_good }

      expect(handled).to eq([:on_good])
    end

    it "does not execute on_good for failed" do
      task = create_failing_task

      result = task.execute
      handled = []

      result.on(:good) { handled << :on_good }

      expect(handled).to be_empty
    end

    it "executes on_bad for skipped" do
      task = create_skipping_task

      result = task.execute
      handled = []

      result.on(:bad) { handled << :on_bad }

      expect(handled).to eq([:on_bad])
    end

    it "executes on_bad for failed" do
      task = create_failing_task

      result = task.execute
      handled = []

      result.on(:bad) { handled << :on_bad }

      expect(handled).to eq([:on_bad])
    end

    it "does not execute on_bad for success" do
      task = create_successful_task

      result = task.execute
      handled = []

      result.on(:bad) { handled << :on_bad }

      expect(handled).to be_empty
    end
  end

  context "when chaining handlers" do
    it "allows method chaining" do
      task = create_successful_task

      result = task.execute
      handled = []

      result
        .on(:success) { handled << :success }
        .on(:complete) { handled << :complete }
        .on(:good) { handled << :good }

      expect(handled).to eq(%i[success complete good])
    end

    it "chains handlers regardless of outcome" do
      task = create_failing_task

      result = task.execute
      handled = []

      result
        .on(:success) { handled << :success }
        .on(:failed) { handled << :failed }
        .on(:complete) { handled << :complete }
        .on(:interrupted) { handled << :interrupted }
        .on(:good) { handled << :good }
        .on(:bad) { handled << :bad }

      expect(handled).to eq(%i[failed interrupted bad])
    end
  end

  context "when accessing result data in handlers" do
    it "provides access to result in handler" do
      task = create_task_class do
        def work
          context.value = 42
        end
      end

      result = task.execute
      captured_value = nil

      result.on(:success) { |r| captured_value = r.context.value }

      expect(captured_value).to eq(42)
    end

    it "provides access to metadata in handler" do
      task = create_task_class do
        def work
          fail!("Test failure", error_code: "TEST.FAILED", retry_count: 3)
        end
      end

      result = task.execute
      captured_metadata = nil

      result.on(:failed) { |r| captured_metadata = r.metadata }

      expect(captured_metadata).to include(error_code: "TEST.FAILED", retry_count: 3)
    end

    it "provides access to task in handler" do
      task = create_task_class(name: "TestTask") do
        def work = nil
      end

      result = task.execute
      captured_task_class = nil

      result.on(:success) { |r| captured_task_class = r.task.class.name }

      expect(captured_task_class).to match(/TestTask/)
    end
  end

  context "when using handlers for control flow" do
    it "uses handlers for conditional logic" do
      success_task = create_successful_task
      failed_task = create_failing_task

      success_outcome = nil
      failed_outcome = nil

      success_task
        .execute
        .on(:success) { success_outcome = "success_path" }
        .on(:failed) { success_outcome = "failure_path" }

      failed_task
        .execute
        .on(:success) { failed_outcome = "success_path" }
        .on(:failed) { failed_outcome = "failure_path" }

      expect(success_outcome).to eq("success_path")
      expect(failed_outcome).to eq("failure_path")
    end

    it "uses handlers for side effects" do
      task = create_task_class do
        def work
          context.value = 100
        end
      end

      notifications = []

      task
        .execute
        .on(:success) { |r| notifications << "Processed: #{r.context.value}" }
        .on(:complete) { notifications << "Completed" }

      expect(notifications).to eq(["Processed: 100", "Completed"])
    end
  end

  context "when combining with block execution" do
    it "allows using both block and handlers" do
      task = create_successful_task

      block_executed = false
      handler_executed = false
      captured_result = nil

      task.execute do |r|
        block_executed = true
        captured_result = r
      end

      captured_result.on(:success) { handler_executed = true }

      expect(block_executed).to be(true)
      expect(handler_executed).to be(true)
    end
  end

  context "when using handlers for cleanup" do
    it "executes cleanup on any outcome" do
      success_task = create_successful_task
      failed_task = create_failing_task
      skipped_task = create_skipping_task

      cleanup_count = 0

      success_task.execute.on(:good) { cleanup_count += 1 }
      failed_task.execute.on(:bad) { cleanup_count += 1 }
      skipped_task.execute.on(:bad) { cleanup_count += 1 }

      expect(cleanup_count).to eq(3)
    end
  end
end
