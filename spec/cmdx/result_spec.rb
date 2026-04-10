# frozen_string_literal: true

RSpec.describe CMDx::Result do
  let(:context) { CMDx::Context.build(x: 1) }
  let(:task) { instance_double("CMDx::Task", class: Class.new) }
  subject(:result) { described_class.new(task: task, context: context) }

  describe "initial state" do
    it "starts as initialized/success" do
      expect(result).to be_initialized
      expect(result).to be_success
      expect(result).not_to be_executed
    end
  end

  describe "state transitions" do
    it "transitions to executing" do
      result.transition_to_executing!
      expect(result).to be_executing
    end

    it "transitions to complete" do
      result.transition_to_executing!
      result.transition_to_complete!
      expect(result).to be_complete
      expect(result).to be_executed
    end
  end

  describe "#skip!" do
    it "sets status to skipped and state to interrupted" do
      result.skip!("not needed")
      expect(result).to be_skipped
      expect(result).to be_interrupted
      expect(result.reason).to eq("not needed")
      expect(result.cause).to be_a(CMDx::SkipFault)
    end

    it "is idempotent" do
      result.skip!("first")
      expect { result.skip!("second") }.not_to raise_error
    end

    it "cannot transition from failed" do
      result.fail!("bad")
      expect { result.skip!("nope") }.to raise_error(RuntimeError)
    end
  end

  describe "#fail!" do
    it "sets status to failed and state to interrupted" do
      result.fail!("broken", code: 500)
      expect(result).to be_failed
      expect(result).to be_interrupted
      expect(result.reason).to eq("broken")
      expect(result.metadata[:code]).to eq(500)
      expect(result.cause).to be_a(CMDx::FailFault)
    end
  end

  describe "#good? / #bad?" do
    it "success is good and not bad" do
      expect(result).to be_good
      expect(result).not_to be_bad
    end

    it "skipped is both good and bad" do
      result.skip!
      expect(result).to be_good
      expect(result).to be_bad
    end

    it "failed is bad and not good" do
      result.fail!
      expect(result).to be_bad
      expect(result).not_to be_good
    end
  end

  describe "#on" do
    it "executes the block for matching status" do
      called = false
      result.on(:success) { called = true }
      expect(called).to be(true)
    end

    it "skips block for non-matching status" do
      called = false
      result.on(:failed) { called = true }
      expect(called).to be(false)
    end

    it "is chainable" do
      values = []
      result.on(:success) { values << :s }.on(:failed) { values << :f }
      expect(values).to eq([:s])
    end

    it "raises without a block" do
      expect { result.on(:success) }.to raise_error(ArgumentError)
    end
  end

  describe "pattern matching" do
    it "supports array deconstruction" do
      case result
      in ["initialized", "success", *]
        matched = true
      end
      expect(matched).to be(true)
    end

    it "supports hash deconstruction" do
      case result
      in { state: "initialized", status: "success" }
        matched = true
      end
      expect(matched).to be(true)
    end
  end

  describe "#dry_run?" do
    it "returns true when context has dry_run" do
      ctx = CMDx::Context.build(dry_run: true)
      r = described_class.new(task: task, context: ctx)
      expect(r).to be_dry_run
    end
  end
end
