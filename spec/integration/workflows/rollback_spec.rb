# frozen_string_literal: true

RSpec.describe "Workflow saga rollback", type: :feature do
  after { CMDx::Chain.clear }

  def task_with_rollback(name:, work_label: name.downcase.to_sym, base: CMDx::Task)
    create_task_class(base:, name:) do
      define_method(:work) { (context.executed ||= []) << work_label }
      define_method(:rollback) { (context.rolled ||= []) << work_label }
    end
  end

  describe "sequential pipeline" do
    it "rolls back previously successful tasks in reverse order; failing task handled by Runtime" do
      a = task_with_rollback(name: "A", work_label: :a)
      b = task_with_rollback(name: "B", work_label: :b)
      c = create_task_class(name: "C") do
        define_method(:work) do
          (context.executed ||= []) << :c
          fail!("boom")
        end
        define_method(:rollback) { (context.rolled ||= []) << :c }
      end

      workflow = create_workflow_class { tasks a, b, c }
      result = workflow.execute

      expect(result).to be_failed
      expect(result.context.executed).to eq(%i[a b c])
      expect(result.context.rolled).to eq(%i[c b a])
    end

    it "excludes skipped tasks from rollback" do
      a = task_with_rollback(name: "A", work_label: :a)
      s = create_task_class(name: "S") do
        define_method(:work) do
          (context.executed ||= []) << :s
          skip!("nope")
        end
        define_method(:rollback) { (context.rolled ||= []) << :s }
      end
      b = task_with_rollback(name: "B", work_label: :b)
      f = create_task_class(name: "F") do
        define_method(:work) { fail!("boom") }
      end

      workflow = create_workflow_class { tasks a, s, b, f }
      result = workflow.execute

      expect(result).to be_failed
      expect(result.context.rolled).to eq(%i[b a])
    end

    it "does not invoke rollback when the workflow succeeds" do
      a = task_with_rollback(name: "A", work_label: :a)
      b = task_with_rollback(name: "B", work_label: :b)

      workflow = create_workflow_class { tasks a, b }
      result = workflow.execute

      expect(result).to be_success
      expect(result.context).not_to respond_to(:rolled)
    end

    it "is a no-op for tasks without #rollback" do
      a = create_task_class(name: "A") { define_method(:work) { context.a = true } }
      f = create_task_class(name: "F") { define_method(:work) { fail!("boom") } }

      workflow = create_workflow_class { tasks a, f }
      expect { workflow.execute }.not_to raise_error
    end
  end

  describe "continue_on_failure" do
    it "rolls back successful tasks within the failing group in reverse order" do
      a = task_with_rollback(name: "A", work_label: :a)
      b = create_task_class(name: "B") do
        define_method(:work) { fail!("boom") }
      end
      c = task_with_rollback(name: "C", work_label: :c)

      workflow = create_workflow_class { tasks a, b, c, continue_on_failure: true }
      result = workflow.execute

      expect(result).to be_failed
      expect(result.context.rolled).to eq(%i[c a])
    end
  end

  describe "across groups" do
    it "rolls back successes from earlier groups when a later group fails" do
      a = task_with_rollback(name: "A", work_label: :a)
      b = task_with_rollback(name: "B", work_label: :b)
      f = create_task_class(name: "F") { define_method(:work) { fail!("boom") } }

      workflow = create_workflow_class do
        tasks a
        tasks b
        tasks f
      end
      result = workflow.execute

      expect(result).to be_failed
      expect(result.context.rolled).to eq(%i[b a])
    end
  end

  describe "parallel groups" do
    it "invokes rollback on each successful instance when the group fails" do
      mailbox = []
      mutex   = Mutex.new
      record  = ->(label) { mutex.synchronize { mailbox << label } }

      a = create_task_class(name: "A") { define_method(:work) { context.a = true } }
      a.define_method(:rollback) { record.call(:a) }
      b = create_task_class(name: "B") { define_method(:work) { fail!("boom") } }
      c = create_task_class(name: "C") { define_method(:work) { context.c = true } }
      c.define_method(:rollback) { record.call(:c) }

      workflow = create_workflow_class { tasks a, b, c, strategy: :parallel, continue_on_failure: true }
      result = workflow.execute

      expect(result).to be_failed
      expect(mailbox.sort).to eq(%i[a c])
    end
  end

  describe "rollback raising" do
    it "propagates as the workflow's failure cause (developer's responsibility)" do
      b = create_task_class(name: "B") do
        define_method(:work) { context.b = true }
        define_method(:rollback) { raise "compensator boom" }
      end
      f = create_task_class(name: "F") do
        define_method(:work) { fail!("orig") }
      end

      workflow = create_workflow_class { tasks b, f }

      result = workflow.execute
      expect(result).to be_failed
      expect(result.cause).to be_a(RuntimeError).and have_attributes(message: "compensator boom")
    end

    it "re-raises under execute!" do
      b = create_task_class(name: "B") do
        define_method(:work) { context.b = true }
        define_method(:rollback) { raise "compensator boom" }
      end
      f = create_task_class(name: "F") do
        define_method(:work) { fail!("orig") }
      end

      workflow = create_workflow_class { tasks b, f }

      expect { workflow.execute! }.to raise_error(RuntimeError, "compensator boom")
    end
  end

  describe "result#rolled_back?" do
    it "is true for compensated successful tasks" do
      a = task_with_rollback(name: "A", work_label: :a)
      f = create_task_class(name: "F") { define_method(:work) { fail!("boom") } }

      workflow = create_workflow_class { tasks a, f }
      result   = workflow.execute

      a_result = result.chain.find { |r| r.task == a }
      expect(a_result).to have_attributes(success?: true, rolled_back?: true)
    end
  end
end
