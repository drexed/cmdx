# frozen_string_literal: true

RSpec.describe "Workflow parallel execution", type: :feature do
  after { CMDx::Chain.clear }

  describe "successful parallel execution" do
    it "merges context contributions from every task" do
      a = create_task_class(name: "A") { define_method(:work) { context.a = "from_a" } }
      b = create_task_class(name: "B") { define_method(:work) { context.b = "from_b" } }

      workflow = create_workflow_class { tasks a, b, strategy: :parallel }

      result = workflow.execute

      expect(result).to have_attributes(status: CMDx::Signal::SUCCESS)
      expect(result.context).to have_attributes(a: "from_a", b: "from_b")
    end

    it "isolates writes between parallel tasks (each runs on a deep-dup'd context)" do
      a = create_task_class(name: "A") do
        define_method(:work) do
          context.shared = "modified_by_a"
          context.a = true
        end
      end
      b = create_task_class(name: "B") do
        define_method(:work) do
          context.b_saw = context[:shared]
          context.b = true
        end
      end

      workflow = create_workflow_class { tasks a, b, strategy: :parallel }

      result = workflow.execute(shared: "original")

      expect(result.context).to have_attributes(a: true, b: true, b_saw: "original")
    end

    it "shares a single cid across all parallel results" do
      a = create_successful_task(name: "A")
      b = create_successful_task(name: "B")

      workflow = create_workflow_class { tasks a, b, strategy: :parallel }

      result = workflow.execute

      expect(result.chain.map(&:cid).uniq.size).to eq(1)
      expect(result.chain.size).to eq(3)
    end
  end

  describe "failure handling" do
    it "reports failure when any parallel task fails and halts subsequent groups" do
      ok = create_task_class(name: "Ok") { define_method(:work) { context.ok = true } }
      fl = create_failing_task(name: "Fail", reason: "parallel boom")
      after = create_task_class(name: "After") { define_method(:work) { context.ran_after = true } }

      workflow = create_workflow_class do
        tasks ok, fl, strategy: :parallel
        task after
      end

      result = workflow.execute

      expect(result).to have_attributes(status: CMDx::Signal::FAILED, reason: "parallel boom")
      expect(result.context[:ok]).to be(true)
      expect(result.context[:ran_after]).to be_nil
    end

    it "raises Fault under execute!" do
      fl = create_failing_task(name: "Fail", reason: "strict")
      workflow = create_workflow_class { tasks fl, strategy: :parallel }

      expect { workflow.execute! }.to raise_error(CMDx::Fault, "strict")
    end
  end

  describe "pool sizing" do
    it "finishes every task even when pool_size is smaller than the task count" do
      a = create_task_class(name: "A") { define_method(:work) { context.a = true } }
      b = create_task_class(name: "B") { define_method(:work) { context.b = true } }
      c = create_task_class(name: "C") { define_method(:work) { context.c = true } }

      workflow = create_workflow_class { tasks a, b, c, strategy: :parallel, pool_size: 2 }

      expect(workflow.execute.context).to have_attributes(a: true, b: true, c: true)
    end
  end

  describe "mixing sequential and parallel groups" do
    it "threads context through sequential -> parallel -> sequential" do
      setup = create_task_class(name: "Setup") { define_method(:work) { context.setup = true } }
      a = create_task_class(name: "ParA") { define_method(:work) { context.par_a = context[:setup] } }
      b = create_task_class(name: "ParB") { define_method(:work) { context.par_b = context[:setup] } }
      done = create_task_class(name: "Done") do
        define_method(:work) { context.finalized = context[:par_a] && context[:par_b] }
      end

      workflow = create_workflow_class do
        task setup
        tasks a, b, strategy: :parallel
        task done
      end

      result = workflow.execute

      expect(result.context).to have_attributes(setup: true, par_a: true, par_b: true, finalized: true)
    end
  end

  describe "continue_on_failure" do
    it "drains pending parallel tasks after the first failure by default" do
      ok = create_task_class(name: "Ok") { define_method(:work) { context.ok = true } }
      fl = create_failing_task(name: "Fail", reason: "fast boom")
      never = create_task_class(name: "Never") { define_method(:work) { context.never_ran = true } }

      workflow = create_workflow_class do
        tasks ok, fl, never, strategy: :parallel, pool_size: 1
      end

      result = workflow.execute

      expect(result).to have_attributes(status: CMDx::Signal::FAILED, reason: "fast boom")
      expect(result.context[:ok]).to be(true)
      expect(result.context[:never_ran]).to be_nil
    end

    it "runs every task and aggregates failures when continue_on_failure is true" do
      ok = create_task_class(name: "Ok") { define_method(:work) { context.ok = true } }
      a = create_failing_task(name: "A", reason: "a-boom")
      b = create_failing_task(name: "B", reason: "b-boom")

      workflow = create_workflow_class do
        tasks ok, a, b, strategy: :parallel, continue_on_failure: true
      end

      result = workflow.execute

      expect(result).to be_failed
      expect(result.context[:ok]).to be(true)
      keys = result.errors.to_h.keys
      expect(keys.any? { |k| k.to_s.end_with?(".failed") && k.to_s.start_with?("A") }).to be(true)
      expect(keys.any? { |k| k.to_s.end_with?(".failed") && k.to_s.start_with?("B") }).to be(true)
    end
  end

  describe "concurrency" do
    it "actually runs tasks on separate threads" do
      a = create_task_class(name: "A") { define_method(:work) { context.a_thread = Thread.current.object_id } }
      b = create_task_class(name: "B") { define_method(:work) { context.b_thread = Thread.current.object_id } }

      workflow = create_workflow_class { tasks a, b, strategy: :parallel }
      result = workflow.execute

      expect(result.context[:a_thread]).not_to eq(Thread.current.object_id)
      expect(result.context[:b_thread]).not_to eq(Thread.current.object_id)
    end
  end
end
