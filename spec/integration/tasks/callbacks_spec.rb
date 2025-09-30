# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task callbacks", type: :feature do
  context "when defining lifecycle callbacks" do
    context "with before_validation" do
      it "executes before attribute validation" do
        task = create_task_class do
          before_validation :track_validation

          required :value

          def work
            context.executed = true
          end

          private

          def track_validation
            (context.callbacks ||= []) << :before_validation
          end
        end

        result = task.execute(value: "test")

        expect(result).to have_been_success
        expect(result).to have_matching_context(callbacks: [:before_validation], executed: true)
      end
    end

    context "with before_execution" do
      it "executes before the work method" do
        task = create_task_class do
          before_execution :setup_data

          def work
            (context.callbacks ||= []) << :work
          end

          private

          def setup_data
            (context.callbacks ||= []) << :before_execution
          end
        end

        result = task.execute

        expect(result).to have_been_success
        expect(result).to have_matching_context(callbacks: %i[before_execution work])
      end
    end

    context "with on_complete" do
      it "executes after successful completion" do
        task = create_task_class do
          on_complete :track_complete

          def work
            (context.callbacks ||= []) << :work
          end

          private

          def track_complete
            (context.callbacks ||= []) << :on_complete
          end
        end

        result = task.execute

        expect(result).to have_been_success
        expect(result).to have_matching_context(callbacks: %i[work on_complete])
      end
    end

    context "with on_interrupted" do
      it "executes after interruption" do
        task = create_task_class do
          on_interrupted :track_interrupted

          def work
            fail!("Test failure")
          end

          private

          def track_interrupted
            (context.callbacks ||= []) << :on_interrupted
          end
        end

        result = task.execute

        expect(result).to have_been_failure(reason: "Test failure")
        expect(result).to have_matching_context(callbacks: [:on_interrupted])
      end
    end

    context "with on_executed" do
      it "executes after any outcome" do
        success_task = create_task_class do
          on_executed :track_executed

          def work
            (context.callbacks ||= []) << :success
          end

          private

          def track_executed
            (context.callbacks ||= []) << :on_executed
          end
        end

        failed_task = create_task_class do
          on_executed :track_executed

          def work
            fail!("Test")
          end

          private

          def track_executed
            (context.callbacks ||= []) << :on_executed
          end
        end

        success_result = success_task.execute
        failed_result = failed_task.execute

        expect(success_result).to have_been_success
        expect(success_result).to have_matching_context(callbacks: %i[success on_executed])

        expect(failed_result).to have_been_failure(reason: "Test")
        expect(failed_result).to have_matching_context(callbacks: [:on_executed])
      end
    end

    context "with on_success" do
      it "executes only on success" do
        task = create_task_class do
          on_success :track_success

          def work
            (context.callbacks ||= []) << :work
          end

          private

          def track_success
            (context.callbacks ||= []) << :on_success
          end
        end

        result = task.execute

        expect(result).to have_been_success
        expect(result).to have_matching_context(callbacks: %i[work on_success])
      end

      it "does not execute on failure" do
        task = create_task_class do
          on_success :track_success

          def work
            fail!("Test")
          end

          private

          def track_success
            (context.callbacks ||= []) << :on_success
          end
        end

        result = task.execute

        expect(result).to have_been_failure(reason: "Test")
        expect(result).to have_empty_context
      end
    end

    context "with on_skipped" do
      it "executes only when skipped" do
        task = create_task_class do
          on_skipped :track_skipped

          def work
            skip!("Test skip")
          end

          private

          def track_skipped
            (context.callbacks ||= []) << :on_skipped
          end
        end

        result = task.execute

        expect(result).to have_been_skipped(reason: "Test skip")
        expect(result).to have_matching_context(callbacks: [:on_skipped])
      end
    end

    context "with on_failed" do
      it "executes only on failure" do
        task = create_task_class do
          on_failed :track_failed

          def work
            fail!("Test failure")
          end

          private

          def track_failed
            (context.callbacks ||= []) << :on_failed
          end
        end

        result = task.execute

        expect(result).to have_been_failure(reason: "Test failure")
        expect(result).to have_matching_context(callbacks: [:on_failed])
      end
    end

    context "with on_good" do
      it "executes on success" do
        task = create_task_class do
          on_good :track_good

          def work
            (context.callbacks ||= []) << :work
          end

          private

          def track_good
            (context.callbacks ||= []) << :on_good
          end
        end

        result = task.execute

        expect(result).to have_been_success
        expect(result).to have_matching_context(callbacks: %i[work on_good])
      end

      it "executes when skipped" do
        task = create_task_class do
          on_good :track_good

          def work
            skip!("Test")
          end

          private

          def track_good
            (context.callbacks ||= []) << :on_good
          end
        end

        result = task.execute

        expect(result).to have_been_skipped(reason: "Test")
        expect(result).to have_matching_context(callbacks: [:on_good])
      end
    end

    context "with on_bad" do
      it "executes when skipped" do
        task = create_task_class do
          on_bad :track_bad

          def work
            skip!("Test")
          end

          private

          def track_bad
            (context.callbacks ||= []) << :on_bad
          end
        end

        result = task.execute

        expect(result).to have_been_skipped(reason: "Test")
        expect(result).to have_matching_context(callbacks: [:on_bad])
      end

      it "executes on failure" do
        task = create_task_class do
          on_bad :track_bad

          def work
            fail!("Test")
          end

          private

          def track_bad
            (context.callbacks ||= []) << :on_bad
          end
        end

        result = task.execute

        expect(result).to have_been_failure(reason: "Test")
        expect(result).to have_matching_context(callbacks: [:on_bad])
      end
    end
  end

  context "when using proc or lambda callbacks" do
    it "executes proc callbacks" do
      task = create_task_class do
        before_execution proc { (context.callbacks ||= []) << :before_proc }
        on_complete proc { (context.callbacks ||= []) << :complete_proc }

        def work = nil
      end

      result = task.execute

      expect(result).to have_been_success
      expect(result).to have_matching_context(callbacks: %i[before_proc complete_proc])
    end

    it "executes lambda callbacks" do
      task = create_task_class do
        before_execution -> { (context.callbacks ||= []) << :before_lambda }
        on_complete -> { (context.callbacks ||= []) << :complete_lambda }

        def work = nil
      end

      result = task.execute

      expect(result).to have_been_success
      expect(result).to have_matching_context(callbacks: %i[before_lambda complete_lambda])
    end

    it "executes class-based callbacks" do
      setup_callback = Class.new do
        def call(task)
          (task.context.callbacks ||= []) << :before_class
        end
      end

      complete_callback = Class.new do
        def call(task)
          (task.context.callbacks ||= []) << :complete_class
        end
      end

      task = create_task_class do
        before_execution setup_callback.new
        on_complete complete_callback.new

        def work = nil
      end

      result = task.execute

      expect(result).to have_been_success
      expect(result).to have_matching_context(callbacks: %i[before_class complete_class])
    end
  end

  context "when using conditional callbacks" do
    it "executes callbacks with if condition" do
      task = create_task_class do
        before_execution :setup_data, if: :should_setup?

        def work
          (context.callbacks ||= []) << :work
        end

        private

        def setup_data
          (context.callbacks ||= []) << :before_execution
        end

        def should_setup?
          context.enable_setup == true
        end
      end

      enabled_result = task.execute(enable_setup: true)
      disabled_result = task.execute(enable_setup: false)

      expect(enabled_result).to have_been_success
      expect(enabled_result).to have_matching_context(callbacks: %i[before_execution work])

      expect(disabled_result).to have_been_success
      expect(disabled_result).to have_matching_context(callbacks: [:work])
    end

    it "executes callbacks with unless condition" do
      task = create_task_class do
        before_execution :setup_data, unless: :skip_setup?

        def work
          (context.callbacks ||= []) << :work
        end

        private

        def setup_data
          (context.callbacks ||= []) << :before_execution
        end

        def skip_setup?
          context.skip_setup == true
        end
      end

      enabled_result = task.execute(skip_setup: false)
      disabled_result = task.execute(skip_setup: true)

      expect(enabled_result).to have_been_success
      expect(enabled_result).to have_matching_context(callbacks: %i[before_execution work])

      expect(disabled_result).to have_been_success
      expect(disabled_result).to have_matching_context(callbacks: [:work])
    end

    it "executes callbacks with combined if and unless" do
      task = create_task_class do
        before_execution :setup_data, if: :should_setup?, unless: :override_setup?

        def work
          (context.callbacks ||= []) << :work
        end

        private

        def setup_data
          (context.callbacks ||= []) << :before_execution
        end

        def should_setup?
          context.enable_setup == true
        end

        def override_setup?
          context.override == true
        end
      end

      both_true = task.execute(enable_setup: true, override: true)
      if_true_unless_false = task.execute(enable_setup: true, override: false)

      expect(both_true).to have_been_success
      expect(both_true).to have_matching_context(callbacks: [:work])

      expect(if_true_unless_false).to have_been_success
      expect(if_true_unless_false).to have_matching_context(callbacks: %i[before_execution work])
    end
  end

  context "when executing multiple callbacks" do
    it "executes callbacks in declaration order (FIFO)" do
      task = create_task_class do
        before_execution :first_setup
        before_execution :second_setup
        on_complete :first_complete
        on_complete :second_complete

        def work
          (context.callbacks ||= []) << :work
        end

        private

        def first_setup
          (context.callbacks ||= []) << :first_setup
        end

        def second_setup
          (context.callbacks ||= []) << :second_setup
        end

        def first_complete
          (context.callbacks ||= []) << :first_complete
        end

        def second_complete
          (context.callbacks ||= []) << :second_complete
        end
      end

      result = task.execute

      expect(result).to have_been_success
      expect(result).to have_matching_context(
        callbacks: %i[first_setup second_setup work first_complete second_complete]
      )
    end
  end

  context "when removing callbacks" do
    it "removes symbol callbacks" do
      parent_task = create_task_class(name: "ParentTask") do
        before_execution :setup_data

        def work
          (context.callbacks ||= []) << :work
        end

        private

        def setup_data
          (context.callbacks ||= []) << :before_execution
        end
      end

      child_task = create_task_class(base: parent_task, name: "ChildTask") do
        deregister :callback, :before_execution, :setup_data
      end

      result = child_task.execute

      expect(result).to have_been_success
      expect(result).to have_matching_context(callbacks: [:work])
    end
  end
end
