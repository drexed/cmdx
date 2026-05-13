# frozen_string_literal: true

RSpec.describe "Workflow execution", type: :feature do
  after { CMDx::Chain.clear }

  describe "happy path" do
    it "runs every declared task in order and shares a chain" do
      t1 = create_successful_task(name: "T1")
      t2 = create_successful_task(name: "T2")
      t3 = create_successful_task(name: "T3")
      workflow = create_workflow_class { tasks t1, t2, t3 }

      result = workflow.execute

      expect(result).to have_attributes(
        status: CMDx::Signal::SUCCESS,
        state: CMDx::Signal::COMPLETE
      )
      expect(result.chain.size).to eq(4)
      expect(result.chain.map { |r| r.task.name }).to all(be_a(String))
      expect(result.chain.first.type).to eq("Workflow")
      expect(result.chain.last.type).to eq("Task")
      expect(result.chain.first(3).map(&:type)).to eq(%w[Workflow Task Task])
    end
  end

  describe "failure semantics" do
    it "halts on failure and skips subsequent tasks" do
      ok = create_successful_task(name: "Ok")
      fl = create_failing_task(name: "Fail", reason: "boom")
      af = create_successful_task(name: "After")

      workflow = create_workflow_class do
        task ok
        task fl
        task af
      end

      result = workflow.execute

      expect(result).to have_attributes(status: CMDx::Signal::FAILED, reason: "boom")
      expect(result.context[:executed]).to eq(%i[success])
    end

    it "skipped tasks do not halt the pipeline" do
      t1 = create_successful_task(name: "Pre")
      sk = create_skipping_task(name: "Skip")
      t2 = create_successful_task(name: "Post")

      workflow = create_workflow_class do
        task t1
        task sk
        task t2
      end

      expect(workflow.execute).to have_attributes(status: CMDx::Signal::SUCCESS)
    end

    it "propagates the failure through threw_failure/caused_failure" do
      fl = create_failing_task(name: "Fail", reason: "boom")
      workflow = create_workflow_class { task fl }

      result = workflow.execute

      expect(result.caused_failure).not_to be_nil
      expect(result.threw_failure).not_to be_nil
    end
  end

  describe "strict mode" do
    it "raises Fault when a task fails under execute!" do
      fl = create_failing_task(name: "StrictFail", reason: "strict boom")
      workflow = create_workflow_class { task fl }

      expect { workflow.execute! }.to raise_error(CMDx::Fault, "strict boom")
    end
  end

  describe "context flow" do
    it "threads the same context through every task" do
      adder = create_task_class(name: "Adder") do
        define_method(:work) { context.total = (context[:total] || context[:seed]) + 5 }
      end
      doubler = create_task_class(name: "Doubler") do
        define_method(:work) { context.total = context[:total] * 2 }
      end

      workflow = create_workflow_class do
        task adder
        task doubler
      end

      expect(workflow.execute(seed: 10).context[:total]).to eq(30)
    end
  end

  describe "empty and invalid pipelines" do
    it "succeeds when no tasks are declared" do
      expect(create_workflow_class.execute).to have_attributes(status: CMDx::Signal::SUCCESS)
    end

    it "raises when a group contains no tasks" do
      expect { create_workflow_class { tasks } }.to raise_error(CMDx::DefinitionError, /cannot declare an empty task group/)
    end

    it "rejects non-task arguments" do
      expect { create_workflow_class { task Object } }
        .to raise_error(TypeError, /is not a Task/)
    end

    it "rejects defining #work on a workflow" do
      expect do
        create_workflow_class { define_method(:work) { nil } }
      end.to raise_error(CMDx::ImplementationError, /cannot define .+#work in a workflow/)
    end

    it "fails with an invalid strategy (wrapped by runtime)" do
      t = create_successful_task(name: "T")
      workflow = create_workflow_class { tasks t, strategy: :nope }

      expect(workflow.execute).to have_attributes(
        status: CMDx::Signal::FAILED,
        reason: /invalid pipeline strategy/
      )
    end
  end

  describe "workflow-level integrations" do
    it "runs workflow before_execution callbacks before delegating to the pipeline" do
      t = create_successful_task(name: "T")
      workflow = create_workflow_class do
        before_execution :setup
        task t
        private
        define_method(:setup) { context.setup = true }
      end

      expect(workflow.execute.context[:setup]).to be(true)
    end

    it "validates workflow-level inputs" do
      t = create_successful_task(name: "T")
      workflow = create_workflow_class do
        required :name, coerce: :string
        task t
      end

      expect(workflow.execute(name: "ok")).to have_attributes(status: CMDx::Signal::SUCCESS)
      expect(workflow.execute).to have_attributes(status: CMDx::Signal::FAILED)
    end
  end

  describe "group ordering" do
    it "runs multiple groups in declaration order" do
      a = create_task_class(name: "A") { define_method(:work) { (context.order ||= []) << :a } }
      b = create_task_class(name: "B") { define_method(:work) { (context.order ||= []) << :b } }
      c = create_task_class(name: "C") { define_method(:work) { (context.order ||= []) << :c } }

      workflow = create_workflow_class do
        task a
        tasks b, c
      end

      expect(workflow.execute.context[:order]).to eq(%i[a b c])
    end
  end

  describe "inheritance" do
    it "child workflow inherits parent pipeline and can extend it" do
      a = create_task_class(name: "A") { define_method(:work) { (context.log ||= []) << :a } }
      b = create_task_class(name: "B") { define_method(:work) { (context.log ||= []) << :b } }

      parent = create_workflow_class(name: "Parent") { task a }
      child = create_workflow_class(base: parent, name: "Child") { task b }

      expect(parent.pipeline.size).to eq(1)
      expect(child.pipeline.size).to eq(2)
      expect(child.execute.context[:log]).to eq(%i[a b])
    end
  end
end
