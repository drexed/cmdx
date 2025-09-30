# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Workflow breakpoints", type: :feature do
  context "with default breakpoints" do
    it "continues on skipped tasks" do
      task1 = create_successful_task(name: "Task1")
      task2 = create_skipping_task(name: "Task2", reason: "Skipped")
      task3 = create_successful_task(name: "Task3")

      workflow = create_workflow_class do
        task task1
        task task2
        task task3
      end

      result = workflow.new.execute

      expect(result).to have_been_success
      expect(result.chain.results.size).to eq(4)
      expect(result.chain.results[2].skipped?).to be(true)
    end

    it "halts on failed tasks" do
      task1 = create_successful_task(name: "Task1")
      task2 = create_failing_task(name: "Task2", reason: "Failed")
      task3 = create_successful_task(name: "Task3")

      workflow = create_workflow_class do
        task task1
        task task2
        task task3
      end

      result = workflow.new.execute

      expect(result).to have_been_failure(reason: "Failed", outcome: "interrupted")
      expect(result.chain.results.size).to eq(3)
      expect(result.chain.results[2].failed?).to be(true)
    end
  end

  context "with custom workflow breakpoints" do
    it "halts on both skipped and failed" do
      task1 = create_successful_task(name: "Task1")
      task2 = create_skipping_task(name: "Task2", reason: "Skipped")
      task3 = create_successful_task(name: "Task3")

      workflow = create_workflow_class do
        settings(workflow_breakpoints: %w[skipped failed])

        task task1
        task task2
        task task3
      end

      result = workflow.new.execute

      expect(result).to have_been_skipped(reason: "Skipped")
      expect(result.chain.results.size).to eq(3)
    end

    it "never halts with empty breakpoints" do
      task1 = create_successful_task(name: "Task1")
      task2 = create_failing_task(name: "Task2", reason: "Failed")
      task3 = create_skipping_task(name: "Task3", reason: "Skipped")
      task4 = create_successful_task(name: "Task4")

      workflow = create_workflow_class do
        settings(workflow_breakpoints: [])

        task task1
        task task2
        task task3
        task task4
      end

      result = workflow.new.execute

      expect(result).to have_been_success
      expect(result.chain.results.size).to eq(5)
    end
  end

  context "with group-level breakpoints" do
    it "applies different breakpoints to different groups" do
      critical_task1 = create_successful_task(name: "CriticalTask1")
      critical_task2 = create_skipping_task(name: "CriticalTask2", reason: "Skipped")
      optional_task1 = create_successful_task(name: "OptionalTask1")
      optional_task2 = create_failing_task(name: "OptionalTask2", reason: "Failed")

      workflow = create_workflow_class do
        tasks critical_task1,
              critical_task2,
              workflow_breakpoints: %w[skipped failed]

        tasks optional_task1,
              optional_task2,
              breakpoints: []
      end

      result = workflow.new.execute

      expect(result).to have_been_success
      expect(result.chain.results.size).to eq(5)
    end

    it "respects group breakpoints independently" do
      group1_task1 = create_successful_task(name: "Group1Task1")
      group1_task2 = create_skipping_task(name: "Group1Task2", reason: "Skipped")
      group2_task1 = create_successful_task(name: "Group2Task1")
      group2_task2 = create_skipping_task(name: "Group2Task2", reason: "Skipped")

      workflow = create_workflow_class do
        tasks group1_task1,
              group1_task2,
              breakpoints: %w[skipped]

        tasks group2_task1,
              group2_task2,
              breakpoints: []
      end

      result = workflow.new.execute

      expect(result).to have_been_skipped(reason: "Skipped")
      expect(result.chain.results.size).to eq(3)
    end
  end

  context "when propagating failures" do
    it "throws failures from nested tasks" do
      inner_task = create_failing_task(name: "InnerTask", reason: "Inner failure")

      outer_task = create_task_class(name: "OuterTask") do
        define_method(:work) do
          result = inner_task.execute
          throw!(result) if result.failed?
        end
      end

      workflow = create_workflow_class do
        task outer_task
      end

      result = workflow.new.execute

      expect(result).to have_been_failure(reason: "Inner failure", outcome: "interrupted")
      expect(result.threw_failure?).to be(false)
    end
  end

  context "with bang execution" do
    it "raises on workflow failure" do
      task1 = create_successful_task(name: "Task1")
      task2 = create_failing_task(name: "Task2", reason: "Failed")

      workflow = create_workflow_class do
        task task1
        task task2
      end

      expect { workflow.new.execute(raise: true) }.to raise_error(CMDx::FailFault)
    end
  end

  context "when continuing after failures" do
    it "executes all tasks when breakpoints are empty" do
      task1 = create_successful_task(name: "Task1")
      task2 = create_failing_task(name: "Task2", reason: "Failed")
      task3 = create_successful_task(name: "Task3")

      workflow = create_workflow_class do
        settings(workflow_breakpoints: [])

        task task1
        task task2
        task task3
      end

      result = workflow.new.execute

      expect(result).to have_been_success
      expect(result.chain.results.size).to eq(4)
      expect(result.chain.results[2].failed?).to be(true)
      expect(result.chain.results[3].success?).to be(true)
    end
  end
end
