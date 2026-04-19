# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task callbacks", type: :feature do
  def callback_log_task(status: :success)
    create_task_class(name: "CallbackTask") do
      before_execution  :log_before_execution
      before_validation :log_before_validation
      on_complete       :log_on_complete
      on_interrupted    :log_on_interrupted
      on_success        :log_on_success
      on_skipped        :log_on_skipped
      on_failed         :log_on_failed
      on_ok             :log_on_ok
      on_ko             :log_on_ko

      define_method(:work) do
        case status
        when :success then nil
        when :skip    then skip!("s")
        when :fail    then fail!("f")
        end
      end

      CMDx::Callbacks::EVENTS.each do |event|
        define_method(:"log_#{event}") { (context.log ||= []) << event }
      end
    end
  end

  describe "event firing order" do
    it "fires before_execution, before_validation, on_complete, on_success, on_ok for a successful task" do
      result = callback_log_task(status: :success).execute

      expect(result.context[:log]).to eq(%i[before_execution before_validation on_complete on_success on_ok])
    end

    it "fires before_execution, before_validation, on_interrupted, on_skipped, on_ok for a skipped task" do
      result = callback_log_task(status: :skip).execute

      expect(result.context[:log]).to eq(%i[before_execution before_validation on_interrupted on_skipped on_ok])
    end

    it "fires before_execution, before_validation, on_interrupted, on_failed, on_ko for a failed task" do
      result = callback_log_task(status: :fail).execute

      expect(result.context[:log]).to eq(%i[before_execution before_validation on_interrupted on_failed on_ko])
    end
  end

  describe "callback forms" do
    subject(:result) { task.execute }

    context "with a Symbol pointing to an instance method" do
      let(:task) do
        create_successful_task do
          on_success :note_success
          define_method(:note_success) { context.note = :symbol }
        end
      end

      it "invokes the method in the task instance" do
        expect(result.context[:note]).to eq(:symbol)
      end
    end

    context "with a block" do
      let(:task) do
        create_successful_task do
          on_success { context.note = :block }
        end
      end

      it "runs the block via instance_exec" do
        expect(result.context[:note]).to eq(:block)
      end
    end

    context "with a Proc" do
      let(:task) do
        create_successful_task do
          on_success proc { |t| t.context.note = :proc }
        end
      end

      it "invokes the proc with the task as argument" do
        expect(result.context[:note]).to eq(:proc)
      end
    end

    context "with a callable object" do
      let(:task) do
        handler = Class.new do
          def self.call(task)
            task.context.note = :callable
          end
        end
        create_successful_task do
          on_success handler
        end
      end

      it "delegates to the callable's #call" do
        expect(result.context[:note]).to eq(:callable)
      end
    end

    context "with multiple callbacks on the same event" do
      let(:task) do
        create_successful_task do
          on_success { (context.log ||= []) << :first }
          on_success :second_handler
          on_success { (context.log ||= []) << :third }
          define_method(:second_handler) { (context.log ||= []) << :second }
        end
      end

      it "invokes them in registration order" do
        expect(result.context[:log]).to eq(%i[first second third])
      end
    end
  end

  describe "inheritance" do
    let(:parent) do
      create_successful_task(name: "Parent") do
        on_success { (context.log ||= []) << :parent }
      end
    end

    it "propagates parent callbacks to children while keeping their own" do
      child = create_successful_task(base: parent, name: "Child") do
        on_success { (context.log ||= []) << :child }
      end

      expect(child.execute.context[:log]).to eq(%i[parent child])
    end

    it "does not leak child callbacks back to the parent" do
      create_successful_task(base: parent, name: "Leaky") do
        on_success { (context.log ||= []) << :leaky }
      end

      expect(parent.execute.context[:log]).to eq(%i[parent])
    end
  end

  describe "deregister" do
    let(:task) do
      parent = create_successful_task(name: "Parent") do
        on_success { (context.log ||= []) << :parent }
      end

      create_successful_task(base: parent, name: "Child") do
        deregister :callback, :on_success
      end
    end

    it "removes callbacks for the given event" do
      expect(task.execute.context[:log]).to be_nil
    end
  end

  describe "invalid registration" do
    it "raises when the callback is neither a Symbol nor callable" do
      expect do
        create_task_class(name: "BadCallback") { on_success "not_callable" }
      end.to raise_error(ArgumentError, /must be a Symbol or respond to #call/)
    end

    it "raises when both a callable and a block are provided" do
      expect do
        create_task_class(name: "BothCallback") do
          on_success(proc {}) { nil }
        end
      end.to raise_error(ArgumentError, /either a callable or a block, not both/)
    end

    it "raises on an unknown event name" do
      expect do
        create_task_class(name: "UnknownCallback") { register :callback, :on_bogus, -> {} }
      end.to raise_error(ArgumentError, /unknown event/)
    end
  end

  describe "conditional execution" do
    let(:gate_class) do
      Class.new do
        def self.call(task) = task.context.gate_open == true
      end
    end

    it "runs the callback when an :if Symbol gate evaluates truthy" do
      task = create_successful_task do
        on_success :note_run, if: :messaging_enabled?
        define_method(:note_run) { context.note = :ran }
        define_method(:messaging_enabled?) { context.messaging == :on }
      end

      expect(task.execute(messaging: :on).context[:note]).to eq(:ran)
      expect(task.execute(messaging: :off).context[:note]).to be_nil
    end

    it "skips the callback when an :unless Symbol gate evaluates truthy" do
      task = create_successful_task do
        on_success :note_run, unless: :messaging_blocked?
        define_method(:note_run) { context.note = :ran }
        define_method(:messaging_blocked?) { context.blocked == true }
      end

      expect(task.execute(blocked: false).context[:note]).to eq(:ran)
      expect(task.execute(blocked: true).context[:note]).to be_nil
    end

    it "supports a Proc gate that runs against the task as self" do
      task = create_successful_task do
        on_success :note_run, if: proc { context.flag }
        define_method(:note_run) { context.note = :ran }
      end

      expect(task.execute(flag: true).context[:note]).to eq(:ran)
      expect(task.execute(flag: false).context[:note]).to be_nil
    end

    it "supports a class callable gate invoked with the task" do
      gate = gate_class
      task = create_successful_task do
        on_success :note_run, if: gate
        define_method(:note_run) { context.note = :ran }
      end

      expect(task.execute(gate_open: true).context[:note]).to eq(:ran)
      expect(task.execute(gate_open: false).context[:note]).to be_nil
    end

    it "applies :if and :unless together (both must pass)" do
      task = create_successful_task do
        on_success :note_run, if: :allowed?, unless: :paused?
        define_method(:note_run) { context.note = :ran }
        define_method(:allowed?) { context.allowed == true }
        define_method(:paused?) { context.paused == true }
      end

      expect(task.execute(allowed: true, paused: false).context[:note]).to eq(:ran)
      expect(task.execute(allowed: true, paused: true).context[:note]).to be_nil
      expect(task.execute(allowed: false, paused: false).context[:note]).to be_nil
    end

    it "evaluates each registration's gates independently" do
      task = create_successful_task do
        on_success :note_a, if: :a_open?
        on_success :note_b, if: :b_open?
        define_method(:note_a) { (context.log ||= []) << :a }
        define_method(:note_b) { (context.log ||= []) << :b }
        define_method(:a_open?) { context.a == true }
        define_method(:b_open?) { context.b == true }
      end

      expect(task.execute(a: true, b: false).context[:log]).to eq([:a])
      expect(task.execute(a: false, b: true).context[:log]).to eq([:b])
      expect(task.execute(a: true, b: true).context[:log]).to eq(%i[a b])
      expect(task.execute(a: false, b: false).context[:log]).to be_nil
    end

    it "gates Proc/block callbacks the same as Symbol callbacks" do
      task = create_successful_task do
        on_success(if: :open?) { context.note = :proc_ran }
        define_method(:open?) { context.open == true }
      end

      expect(task.execute(open: true).context[:note]).to eq(:proc_ran)
      expect(task.execute(open: false).context[:note]).to be_nil
    end
  end

  describe "callback interactions" do
    it "runs before_validation before input resolution so it can populate context" do
      task = create_task_class(name: "PrefillTask") do
        before_validation { context.name = "Alice" }
        required :name
        define_method(:work) { context.greeting = "Hi, #{name}" }
      end

      expect(task.execute.context[:greeting]).to eq("Hi, Alice")
    end

    it "fires on_failed even when failure came from a raised exception" do
      task = create_erroring_task do
        on_failed { (context.log ||= []) << :handled_failure }
      end

      expect(task.execute.context[:log]).to eq(%i[handled_failure])
    end
  end
end
