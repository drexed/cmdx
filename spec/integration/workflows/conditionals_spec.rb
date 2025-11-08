# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Workflow conditionals", type: :feature do
  context "when using if conditionals" do
    it "executes task when condition is true" do
      task1 = create_successful_task(name: "Task1")

      workflow = create_workflow_class do
        task task1, if: :should_execute?

        def should_execute?
          context.execute_task == true
        end
      end

      enabled_result = workflow.execute(execute_task: true)
      disabled_result = workflow.execute(execute_task: false)

      expect(enabled_result).to be_successful
      expect(enabled_result.chain.results.size).to eq(2)

      expect(disabled_result).to be_successful
      expect(disabled_result.chain.results.size).to eq(1)
    end

    it "uses proc for if condition" do
      task1 = create_successful_task(name: "Task1")

      workflow = create_workflow_class do
        task task1, if: -> { context.enabled == true }
      end

      enabled_result = workflow.execute(enabled: true)
      disabled_result = workflow.execute(enabled: false)

      expect(enabled_result.chain.results.size).to eq(2)
      expect(disabled_result.chain.results.size).to eq(1)
    end

    it "uses lambda for if condition" do
      task1 = create_successful_task(name: "Task1")

      workflow = create_workflow_class do
        task task1, if: proc { context.enabled == true }
      end

      enabled_result = workflow.execute(enabled: true)
      disabled_result = workflow.execute(enabled: false)

      expect(enabled_result.chain.results.size).to eq(2)
      expect(disabled_result.chain.results.size).to eq(1)
    end
  end

  context "when using unless conditionals" do
    it "executes task when condition is false" do
      task1 = create_successful_task(name: "Task1")

      workflow = create_workflow_class do
        task task1, unless: :should_skip?

        def should_skip?
          context.skip_task == true
        end
      end

      enabled_result = workflow.execute(skip_task: false)
      disabled_result = workflow.execute(skip_task: true)

      expect(enabled_result.chain.results.size).to eq(2)
      expect(disabled_result.chain.results.size).to eq(1)
    end

    it "uses proc for unless condition" do
      task1 = create_successful_task(name: "Task1")

      workflow = create_workflow_class do
        task task1, unless: -> { context.disabled == true }
      end

      enabled_result = workflow.execute(disabled: false)
      disabled_result = workflow.execute(disabled: true)

      expect(enabled_result.chain.results.size).to eq(2)
      expect(disabled_result.chain.results.size).to eq(1)
    end
  end

  context "when combining if and unless" do
    it "requires both conditions to be satisfied" do
      task1 = create_successful_task(name: "Task1")

      workflow = create_workflow_class do
        task task1,
             if: :should_execute?,
             unless: :should_skip?

        def should_execute?
          context.enabled == true
        end

        def should_skip?
          context.override == true
        end
      end

      both_satisfied = workflow.execute(enabled: true, override: false)
      if_false = workflow.execute(enabled: false, override: false)
      unless_false = workflow.execute(enabled: true, override: true)

      expect(both_satisfied.chain.results.size).to eq(2)
      expect(if_false.chain.results.size).to eq(1)
      expect(unless_false.chain.results.size).to eq(1)
    end
  end

  context "when using conditionals with groups" do
    it "applies condition to all tasks in group" do
      task1 = create_successful_task(name: "Task1")
      task2 = create_successful_task(name: "Task2")
      task3 = create_successful_task(name: "Task3")

      workflow = create_workflow_class do
        tasks task1, task2, task3, if: :group_enabled?

        def group_enabled?
          context.enable_group == true
        end
      end

      enabled_result = workflow.execute(enable_group: true)
      disabled_result = workflow.execute(enable_group: false)

      expect(enabled_result.chain.results.size).to eq(4)
      expect(disabled_result.chain.results.size).to eq(1)
    end
  end

  context "when conditionals affect execution flow" do
    it "skips tasks based on runtime conditions" do
      setup_task = create_task_class(name: "SetupTask") do
        def work
          context.setup_complete = true
        end
      end
      conditional_task = create_successful_task(name: "ConditionalTask")
      final_task = create_successful_task(name: "FinalTask")

      workflow = create_workflow_class do
        task setup_task
        task conditional_task, if: proc { context.setup_complete == true }
        task final_task
      end

      result = workflow.execute

      expect(result).to be_successful
      expect(result.chain.results.size).to eq(4)
      expect(result).to have_matching_context(setup_complete: true)
    end
  end

  context "when using complex conditional logic" do
    it "evaluates complex conditions" do
      task1 = create_successful_task(name: "Task1")

      workflow = create_workflow_class do
        task task1, if: proc {
          context.env == "production" && context.feature_enabled == true
        }
      end

      prod_enabled = workflow.execute(env: "production", feature_enabled: true)
      prod_disabled = workflow.execute(env: "production", feature_enabled: false)
      dev_enabled = workflow.execute(env: "development", feature_enabled: true)

      expect(prod_enabled.chain.results.size).to eq(2)
      expect(prod_disabled.chain.results.size).to eq(1)
      expect(dev_enabled.chain.results.size).to eq(1)
    end
  end
end
