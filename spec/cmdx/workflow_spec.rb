# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Workflow do
  describe ".pipeline" do
    it "defaults to an empty array" do
      workflow = create_workflow_class
      expect(workflow.pipeline).to eq([])
    end
  end

  describe ".tasks" do
    it "returns the pipeline when called with no tasks" do
      workflow = create_workflow_class
      expect(workflow.tasks).to be(workflow.pipeline)
    end

    it "appends an ExecutionGroup with options" do
      task = create_successful_task
      workflow = create_workflow_class do
        tasks task, if: proc { true }
      end

      group = workflow.pipeline.first
      expect(group).to be_a(CMDx::Workflow::ExecutionGroup)
      expect(group.tasks).to eq([task])
      expect(group.options[:if]).to be_a(Proc)
    end

    it "supports multiple tasks in a single group" do
      a = create_successful_task
      b = create_successful_task
      workflow = create_workflow_class do
        tasks a, b
      end

      expect(workflow.pipeline.first.tasks).to eq([a, b])
    end

    it "raises TypeError for a non-Task" do
      expect do
        create_workflow_class { tasks "not a task" }
      end.to raise_error(TypeError, /is not a Task/)
    end

    it "is aliased as .task" do
      t = create_successful_task
      workflow = create_workflow_class { task t }
      expect(workflow.pipeline.first.tasks).to eq([t])
    end
  end

  describe "inheritance" do
    it "dups the parent's pipeline into subclasses" do
      a = create_successful_task
      parent = create_workflow_class(name: "ParentFlow") { tasks a }
      child = Class.new(parent)

      expect(child.pipeline).to eq(parent.pipeline)
      expect(child.pipeline).not_to be(parent.pipeline)
    end
  end

  describe "#work" do
    it "delegates to Pipeline.execute" do
      a = create_successful_task
      workflow = create_workflow_class { tasks a }

      expect(CMDx::Pipeline).to receive(:execute).with(an_instance_of(workflow)).and_return(:done)
      instance = workflow.new
      expect(instance.work).to eq(:done)
    end
  end

  describe "work definition guard" do
    it "raises when a workflow subclass tries to define #work" do
      expect do
        Class.new(CMDx::Task) do
          include CMDx::Workflow

          def work; end
        end
      end.to raise_error(CMDx::ImplementationError, /cannot define .*#work in a workflow/)
    end
  end

  describe "integration with Task.execute" do
    it "runs the pipeline and returns a successful result" do
      a = create_successful_task
      workflow = create_workflow_class { tasks a }

      expect(workflow.execute).to be_success
    end
  end
end
