# frozen_string_literal: true

RSpec.describe "Workflow execution" do # rubocop:disable RSpec/DescribeClass
  let(:step_a) do
    Class.new(CMDx::Task) do
      def self.name = "StepA"
      def work = ctx.a = "done"
    end
  end

  let(:step_b) do
    Class.new(CMDx::Task) do
      def self.name = "StepB"
      def work = ctx.b = "done"
    end
  end

  let(:failing_step) do
    Class.new(CMDx::Task) do
      def self.name = "FailStep"
      def work = fail!("step failed")
    end
  end

  describe "sequential workflow" do
    it "executes tasks in order" do
      a = step_a
      b = step_b

      workflow = Class.new(CMDx::Task) do
        include CMDx::Workflow

        def self.name = "SeqWorkflow"

        task a
        task b
      end

      result = workflow.execute
      expect(result).to be_success
      expect(result.context[:a]).to eq("done")
      expect(result.context[:b]).to eq("done")
    end
  end

  describe "workflow with failing step" do
    it "halts on strict failure" do
      a = step_a
      f = failing_step

      workflow = Class.new(CMDx::Task) do
        include CMDx::Workflow

        def self.name = "FailWorkflow"

        task a
        task f
      end

      result = workflow.execute
      expect(result).to be_failed
    end
  end
end
