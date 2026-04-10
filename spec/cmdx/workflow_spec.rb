# frozen_string_literal: true

RSpec.describe CMDx::Workflow do
  before { CMDx.configuration.freeze_results = false }

  let(:step1) do
    Class.new(CMDx::Task) do
      def self.name; "Step1"; end

      def work
        context.steps = (context.steps || []) << "step1"
      end
    end
  end

  let(:step2) do
    Class.new(CMDx::Task) do
      def self.name; "Step2"; end

      def work
        context.steps = (context.steps || []) << "step2"
      end
    end
  end

  let(:failing_step) do
    Class.new(CMDx::Task) do
      def self.name; "FailingStep"; end

      def work
        fail!("step failed")
      end
    end
  end

  let(:skipping_step) do
    Class.new(CMDx::Task) do
      def self.name; "SkippingStep"; end

      def work
        skip!("not needed")
      end
    end
  end

  describe "sequential execution" do
    it "runs tasks in order" do
      s1, s2 = step1, step2
      workflow = Class.new(CMDx::Task) do
        include CMDx::Workflow
        task s1
        task s2
      end

      result = workflow.execute
      expect(result).to be_success
      expect(result.context.steps).to eq(%w[step1 step2])
    end
  end

  describe "failure propagation" do
    it "stops on first failure" do
      s1, fs, s2 = step1, failing_step, step2
      workflow = Class.new(CMDx::Task) do
        include CMDx::Workflow
        task s1
        task fs
        task s2
      end

      result = workflow.execute
      expect(result).to be_failed
      expect(result.context.steps).to eq(%w[step1])
    end
  end

  describe "skip behavior" do
    it "continues past skips by default" do
      s1, ss, s2 = step1, skipping_step, step2
      workflow = Class.new(CMDx::Task) do
        include CMDx::Workflow
        task s1
        task ss
        task s2
      end

      result = workflow.execute
      expect(result.context.steps).to eq(%w[step1 step2])
    end

    it "halts on skip when configured" do
      s1, ss, s2 = step1, skipping_step, step2
      workflow = Class.new(CMDx::Task) do
        include CMDx::Workflow
        settings(workflow_breakpoints: %w[skipped failed])
        task s1
        task ss
        task s2
      end

      result = workflow.execute
      expect(result.context.steps).to eq(%w[step1])
    end
  end

  describe "conditionals" do
    it "skips tasks when condition is false" do
      s1, s2 = step1, step2
      workflow = Class.new(CMDx::Task) do
        include CMDx::Workflow
        task s1, if: -> { false }
        task s2
      end

      result = workflow.execute
      expect(result.context.steps).to eq(%w[step2])
    end

    it "runs tasks when condition is true" do
      s1, s2 = step1, step2
      workflow = Class.new(CMDx::Task) do
        include CMDx::Workflow
        task s1, if: -> { true }
        task s2
      end

      result = workflow.execute
      expect(result.context.steps).to eq(%w[step1 step2])
    end
  end

  describe "parallel execution" do
    it "runs tasks in parallel" do
      s1 = Class.new(CMDx::Task) do
        def self.name; "ParaStep1"; end

        def work
          context.para1 = true
        end
      end

      s2 = Class.new(CMDx::Task) do
        def self.name; "ParaStep2"; end

        def work
          context.para2 = true
        end
      end

      workflow = Class.new(CMDx::Task) do
        include CMDx::Workflow
        tasks s1, s2, strategy: :parallel
      end

      result = workflow.execute
      expect(result).to be_success
      expect(result.context.para1).to be(true)
      expect(result.context.para2).to be(true)
    end
  end

  describe "inheritance" do
    it "inherits workflow tasks" do
      s1, s2 = step1, step2
      parent = Class.new(CMDx::Task) do
        include CMDx::Workflow
        task s1
      end

      child = Class.new(parent) do
        task s2
      end

      result = child.execute
      expect(result).to be_success
      expect(result.context.steps).to eq(%w[step1 step2])
    end
  end
end
