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

      enabled_result = workflow.new(execute_task: true).execute
      CMDx::Chain.clear

      disabled_result = workflow.new(execute_task: false).execute

      expect(enabled_result).to have_been_success
      expect(enabled_result.chain.results.size).to eq(2)

      expect(disabled_result).to have_been_success
      expect(disabled_result.chain.results.size).to eq(1)
    end

    it "uses proc for if condition" do
      task1 = create_successful_task(name: "Task1")

      workflow = create_workflow_class do
        task task1, if: -> { context.enabled == true }
      end

      enabled_result = workflow.new(enabled: true).execute
      CMDx::Chain.clear

      disabled_result = workflow.new(enabled: false).execute

      expect(enabled_result.chain.results.size).to eq(2)
      expect(disabled_result.chain.results.size).to eq(1)
    end

    it "uses lambda for if condition" do
      task1 = create_successful_task(name: "Task1")

      workflow = create_workflow_class do
        task task1, if: proc { context.enabled == true }
      end

      enabled_result = workflow.new(enabled: true).execute
      CMDx::Chain.clear

      disabled_result = workflow.new(enabled: false).execute

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

      enabled_result = workflow.new(skip_task: false).execute
      CMDx::Chain.clear

      disabled_result = workflow.new(skip_task: true).execute

      expect(enabled_result.chain.results.size).to eq(2)
      expect(disabled_result.chain.results.size).to eq(1)
    end

    it "uses proc for unless condition" do
      task1 = create_successful_task(name: "Task1")

      workflow = create_workflow_class do
        task task1, unless: -> { context.disabled == true }
      end

      enabled_result = workflow.new(disabled: false).execute
      CMDx::Chain.clear

      disabled_result = workflow.new(disabled: true).execute

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

      both_satisfied = workflow.new(enabled: true, override: false).execute
      CMDx::Chain.clear

      if_false = workflow.new(enabled: false, override: false).execute
      CMDx::Chain.clear

      unless_false = workflow.new(enabled: true, override: true).execute

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

      enabled_result = workflow.new(enable_group: true).execute
      CMDx::Chain.clear

      disabled_result = workflow.new(enable_group: false).execute

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

      result = workflow.new.execute

      expect(result).to have_been_success
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

      prod_enabled = workflow.new(env: "production", feature_enabled: true).execute
      CMDx::Chain.clear

      prod_disabled = workflow.new(env: "production", feature_enabled: false).execute
      CMDx::Chain.clear

      dev_enabled = workflow.new(env: "development", feature_enabled: true).execute

      expect(prod_enabled.chain.results.size).to eq(2)
      expect(prod_disabled.chain.results.size).to eq(1)
      expect(dev_enabled.chain.results.size).to eq(1)
    end
  end
end
