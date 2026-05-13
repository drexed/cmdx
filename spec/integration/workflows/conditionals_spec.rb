# frozen_string_literal: true

RSpec.describe "Workflow conditionals", type: :feature do
  after { CMDx::Chain.clear }

  let(:guarded_task) do
    create_task_class(name: "Guarded") { define_method(:work) { context.ran = true } }
  end

  describe "if: conditionals" do
    it "runs when a Symbol resolves truthy" do
      t = guarded_task
      workflow = create_workflow_class do
        task t, if: :enabled?
        define_method(:enabled?) { context[:enabled] }
      end

      expect(workflow.execute(enabled: true).context[:ran]).to be(true)
    end

    it "skips when a Symbol resolves falsy" do
      t = guarded_task
      workflow = create_workflow_class do
        task t, if: :enabled?
        define_method(:enabled?) { context[:enabled] }
      end

      expect(workflow.execute(enabled: false).context[:ran]).to be_nil
    end

    it "runs when a Proc resolves truthy (evaluated in the workflow instance)" do
      t = guarded_task
      workflow = create_workflow_class { task t, if: proc { context[:flag] } }

      expect(workflow.execute(flag: true).context[:ran]).to be(true)
    end

    it "supports a lambda" do
      t = guarded_task
      workflow = create_workflow_class { task t, if: -> { context.key?(:trigger) } }

      expect(workflow.execute.context[:ran]).to be_nil
      expect(workflow.execute(trigger: :go).context[:ran]).to be(true)
    end

    it "supports a callable object that receives the workflow" do
      checker = Class.new do
        def call(task) = task.context[:allowed]
      end.new
      t = guarded_task
      workflow = create_workflow_class { task t, if: checker }

      expect(workflow.execute(allowed: true).context[:ran]).to be(true)
      expect(workflow.execute(allowed: false).context[:ran]).to be_nil
    end
  end

  describe "unless: conditionals" do
    it "runs when the guard is falsy" do
      t = guarded_task
      workflow = create_workflow_class do
        task t, unless: :disabled?
        define_method(:disabled?) { context[:disabled] }
      end

      expect(workflow.execute(disabled: false).context[:ran]).to be(true)
    end

    it "skips when the guard is truthy" do
      t = guarded_task
      workflow = create_workflow_class do
        task t, unless: :disabled?
        define_method(:disabled?) { context[:disabled] }
      end

      expect(workflow.execute(disabled: true).context[:ran]).to be_nil
    end
  end

  describe "combining if: and unless:" do
    it "skips when both are specified and unless is truthy" do
      t = guarded_task
      workflow = create_workflow_class { task t, if: proc { true }, unless: proc { true } }

      expect(workflow.execute.context[:ran]).to be_nil
    end

    it "runs only when if: is truthy and unless: is falsy" do
      t = guarded_task
      workflow = create_workflow_class { task t, if: proc { true }, unless: proc { false } }

      expect(workflow.execute.context[:ran]).to be(true)
    end
  end

  describe "group scoping" do
    it "applies conditionals to every task in a sequential group" do
      a = create_task_class(name: "A") { define_method(:work) { context.a = true } }
      b = create_task_class(name: "B") { define_method(:work) { context.b = true } }

      workflow = create_workflow_class do
        tasks a, b, if: proc { !context[:skip_group] }
      end

      result = workflow.execute(skip_group: true)

      expect(result.context[:a]).to be_nil
      expect(result.context[:b]).to be_nil
    end

    it "applies conditionals to every task in a parallel group" do
      a = create_task_class(name: "A") { define_method(:work) { context.a = true } }
      b = create_task_class(name: "B") { define_method(:work) { context.b = true } }

      workflow = create_workflow_class do
        tasks a, b, strategy: :parallel, if: proc { context[:run] }
      end

      result = workflow.execute(run: false)

      expect(result.context[:a]).to be_nil
      expect(result.context[:b]).to be_nil
    end
  end

  describe "mixing groups with different conditions" do
    it "runs groups whose conditions match and skips the rest" do
      a = create_task_class(name: "A") { define_method(:work) { (context.log ||= []) << :a } }
      b = create_task_class(name: "B") { define_method(:work) { (context.log ||= []) << :b } }
      c = create_task_class(name: "C") { define_method(:work) { (context.log ||= []) << :c } }

      workflow = create_workflow_class do
        task a, if: proc { true }
        task b, unless: proc { true }
        task c
      end

      expect(workflow.execute.context[:log]).to eq(%i[a c])
    end
  end

  describe "condition visibility into the workflow" do
    it "Proc conditions can reach task-level context that earlier tasks populated" do
      first = create_task_class(name: "First") { define_method(:work) { context.gate = true } }
      second = create_task_class(name: "Second") { define_method(:work) { context.second_ran = true } }

      workflow = create_workflow_class do
        task first
        task second, if: proc { context[:gate] }
      end

      expect(workflow.execute.context[:second_ran]).to be(true)
    end
  end
end
