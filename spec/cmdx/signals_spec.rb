# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Signals do
  def task_with_context(**ctx)
    klass = Class.new(CMDx::Task) do
      def work; end
    end
    t = klass.allocate
    t.instance_variable_set(:@context, CMDx::Context.new(ctx))
    t
  end

  describe "#success!" do
    it "with halt: true throws :cmdx_signal" do
      task = task_with_context
      caught = catch(:cmdx_signal) do
        task.success!("ok", halt: true, meta: 1)
        :not_thrown
      end
      expect(caught).to eq({ status: :success, reason: "ok", metadata: { meta: 1 } })
    end

    it "with halt: false sets @_success and does not throw" do
      task = task_with_context
      val = catch(:cmdx_signal) do
        task.success!(halt: false, note: "x")
        :inner
      end
      expect(val).to eq(:inner)
      expect(task.instance_variable_get(:@_success)).to eq(
        { reason: nil, metadata: { note: "x" } }
      )
    end
  end

  describe "#fail!" do
    it "with halt: true throws :cmdx_signal with status: :failed" do
      task = task_with_context
      caught = catch(:cmdx_signal) { task.fail!("nope", halt: true) }
      expect(caught[:status]).to eq(:failed)
      expect(caught[:reason]).to eq("nope")
    end

    it "with halt: false sets @_signal" do
      task = task_with_context
      task.fail!("soft", halt: false)
      sig = task.instance_variable_get(:@_signal)
      expect(sig[:status]).to eq(:failed)
      expect(sig[:reason]).to eq("soft")
    end
  end

  describe "#skip!" do
    it "with halt: true throws :cmdx_signal with status: :skipped" do
      task = task_with_context
      caught = catch(:cmdx_signal) { task.skip!("later", halt: true) }
      expect(caught[:status]).to eq(:skipped)
      expect(caught[:reason]).to eq("later")
    end

    it "does not override existing @_signal" do
      task = task_with_context
      task.instance_variable_set(:@_signal, { status: :failed, reason: "first" })
      task.skip!("ignored", halt: false)
      expect(task.instance_variable_get(:@_signal)[:reason]).to eq("first")
    end
  end

  describe "#throw!" do
    it "propagates another result's status" do
      src_class = Class.new(CMDx::Task) do
        def work
          fail!("from source", halt: true)
        end
      end
      other = src_class.execute
      expect(other.status).to eq("failed")

      task = task_with_context
      caught = catch(:cmdx_signal) { task.throw!(other, halt: true) }
      expect(caught[:status]).to eq(:failed)
      expect(caught[:reason]).to eq(other.reason)
      expect(caught[:thrown_from]).to eq(other.task_id)
    end
  end

  describe "#dry_run?" do
    it "reads from context[:dry_run]" do
      expect(task_with_context(dry_run: true).dry_run?).to be(true)
      expect(task_with_context(dry_run: false).dry_run?).to be(false)
      expect(task_with_context.dry_run?).to be(false)
    end
  end
end
