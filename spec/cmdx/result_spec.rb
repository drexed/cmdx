# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Result do
  def build(**attrs)
    defaults = {
      task_id: "task-1",
      task_class: String,
      task_type: "string",
      task_tags: %i[a b],
      state: "complete",
      status: "success",
      reason: nil,
      cause: nil,
      metadata: { k: 1 },
      strict: true,
      retries: 0,
      rolled_back: false,
      context: CMDx::Context.new,
      chain: nil,
      errors: CMDx::Errors.new,
      index: 0
    }
    described_class.new(**defaults, **attrs)
  end

  describe "#initialize" do
    it "freezes the instance" do
      r = build
      expect(r).to be_frozen
    end
  end

  describe "state queries" do
    it "#complete?, #interrupted?, #executed?" do
      expect(build(state: "complete").complete?).to be true
      expect(build(state: "interrupted").interrupted?).to be true
      expect(build(state: "executing").executed?).to be false
      expect(build(state: "complete").executed?).to be true
      expect(build(state: "interrupted").executed?).to be true
    end
  end

  describe "status queries" do
    it "#success?, #skipped?, #failed?" do
      expect(build(status: "success").success?).to be true
      expect(build(status: "skipped").skipped?).to be true
      expect(build(status: "failed").failed?).to be true
    end
  end

  describe "compound queries" do
    it "#good? / #ok?, #bad?, #strict?, #retried?, #rolled_back?, #dry_run?" do
      expect(build.good?).to be true
      expect(build.ok?).to be true
      expect(build(status: "failed").bad?).to be true
      expect(build(strict: false).strict?).to be false
      expect(build(retries: 2).retried?).to be true
      expect(build(rolled_back: true).rolled_back?).to be true

      chain = CMDx::Chain.new(dry_run: true)
      expect(build(chain: chain).dry_run?).to be true
      expect(build.dry_run?).to be false
    end
  end

  describe "#on" do
    it "yields self when a filter matches state or status" do
      r = build(state: "interrupted", status: "failed")
      seen = []
      r.on("nope") { seen << :bad }
      expect(seen).to be_empty

      r.on("interrupted") { seen << :state }
      r.on(:failed) { seen << :status }
      expect(seen).to contain_exactly(:state, :status)
    end
  end

  describe "#deconstruct, #deconstruct_keys" do
    it "supports array and hash pattern matching" do
      r = build(state: "complete", status: "skipped", reason: "n/a")
      expect(r.deconstruct).to eq(["complete", "skipped", "n/a"])

      slice = r.deconstruct_keys(%i[state status])
      expect(slice).to eq({ state: "complete", status: "skipped" })

      full = r.deconstruct_keys
      expect(full).to include(:task_id, :errors, :metadata)
      expect(full[:task_class]).to eq("String")
    end
  end

  describe "#outcome" do
    it "returns a human label for the status" do
      expect(build(status: "success").outcome).to eq("success")
      expect(build(status: "skipped").outcome).to eq("skipped")
      expect(build(status: "failed").outcome).to eq("failed")
    end
  end

  describe "#to_h, #to_s" do
    let(:r) { build(reason: "oops") }

    it "to_h includes core fields and stringifies task_class" do
      h = r.to_h
      expect(h[:task_id]).to eq("task-1")
      expect(h[:task_class]).to eq("String")
      expect(h[:state]).to eq("complete")
      expect(h[:errors]).to eq({})
    end

    it "to_s summarizes status and class" do
      expect(r.to_s).to start_with("[SUCCESS]")
      expect(r.to_s).to include("String")
      expect(r.to_s).to include("(oops)")
    end
  end
end
