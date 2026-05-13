# frozen_string_literal: true

RSpec.describe CMDx::Result do
  let(:chain) { CMDx::Chain.new }
  let(:task_class) { create_task_class(name: "SampleTask") }
  let(:task) { task_class.new }

  def build(signal, **opts)
    described_class.new(chain, task, signal, **opts)
  end

  describe "#initialize" do
    it "freezes the options hash" do
      result = build(CMDx::Signal.success, tid: "abc")
      expect(result.instance_variable_get(:@options)).to be_frozen
    end
  end

  describe "simple delegators" do
    let(:result) { build(CMDx::Signal.success, tid: "rid-1", duration: 0.01) }

    it "returns tid, duration, task, type" do
      expect(result).to have_attributes(
        tid: "rid-1",
        duration: 0.01,
        task: task_class,
        type: "Task"
      )
    end

    it "delegates context/errors to the task" do
      expect(result.context).to be(task.context)
      expect(result.ctx).to be(task.context)
      expect(result.errors).to be(task.errors)
    end

    it "exposes the chain id" do
      expect(result.cid).to eq(chain.id)
    end

    it "reports the full chain results array" do
      other = build(CMDx::Signal.success)
      chain << result
      chain << other

      expect(result.chain.to_a).to eq([result, other])
      expect(other.chain.to_a).to eq([result, other])
    end

    it "index reports the index of self" do
      chain << result
      expect(result.index).to eq(0)
    end
  end

  describe "signal delegators" do
    it "exposes state/status predicates" do
      result = build(CMDx::Signal.success)
      expect(result).to have_attributes(
        state: "complete", status: "success",
        complete?: true, interrupted?: false,
        success?: true, skipped?: false, failed?: false,
        ok?: true, ko?: false
      )
    end

    it "exposes reason/metadata/cause" do
      sig = CMDx::Signal.failed("boom", metadata: { k: 1 }, cause: StandardError.new("x"))
      result = build(sig)

      expect(result.reason).to eq("boom")
      expect(result.metadata).to eq(k: 1)
      expect(result.cause).to be_a(StandardError)
    end
  end

  describe "#on" do
    let(:success) { build(CMDx::Signal.success) }
    let(:failed)  { build(CMDx::Signal.failed) }

    it "yields when any of the listed events match" do
      yielded = []
      success.on(:success) { |r| yielded << r }
      expect(yielded).to eq([success])
    end

    it "does not yield when no events match" do
      yielded = []
      success.on(:failed, :ko) { |r| yielded << r }
      expect(yielded).to be_empty
    end

    it "returns self" do
      expect(failed.on(:failed) { |_| nil }).to be(failed)
    end

    it "raises without a block" do
      expect { success.on(:success) }.to raise_error(ArgumentError, /Result#on requires a block/)
    end

    it "raises on an unknown event" do
      expect { success.on(:bogus) { |_| nil } }.to raise_error(ArgumentError, /unknown Result#on event :bogus/)
    end
  end

  describe "failure helpers" do
    context "when the result is not failed" do
      let(:result) { build(CMDx::Signal.success) }

      it "caused_failure/threw_failure are nil and predicates are false" do
        expect(result.caused_failure).to be_nil
        expect(result.threw_failure).to be_nil
        expect(result.caused_failure?).to be(false)
        expect(result.thrown_failure?).to be(false)
      end
    end

    context "when the result is failed with no Fault cause" do
      let(:result) { build(CMDx::Signal.failed("boom")) }

      it "self is both the caused and threw failure" do
        expect(result.caused_failure).to be(result)
        expect(result.threw_failure).to be(result)
        expect(result.caused_failure?).to be(true)
        expect(result.thrown_failure?).to be(false)
      end
    end

    context "when the result was echoed from an upstream failure" do
      let(:original_failure) do
        build(CMDx::Signal.failed("origin")).tap { |r| chain << r }
      end
      let(:rethrown) do
        sig = CMDx::Signal.echoed(original_failure, cause: CMDx::Fault.new(original_failure))
        build(sig).tap { |r| chain << r }
      end

      before do
        original_failure
        rethrown
      end

      it "exposes the upstream as origin" do
        expect(rethrown.origin).to be(original_failure)
      end

      it "threw_failure points at the immediate upstream failure" do
        expect(rethrown.threw_failure).to be(original_failure)
        expect(rethrown.thrown_failure?).to be(true)
      end

      it "caused_failure walks back to the originator" do
        expect(rethrown.caused_failure).to be(original_failure)
        expect(rethrown.caused_failure?).to be(false)
      end
    end
  end

  describe "option-backed predicates" do
    it "retries/retried?/strict?/deprecated?/rolled_back?" do
      r1 = build(CMDx::Signal.success, retries: 2)
      r2 = build(CMDx::Signal.success, strict: true, deprecated: true, rolled_back: true)
      r3 = build(CMDx::Signal.success)

      expect(r1.retries).to eq(2)
      expect(r1.retried?).to be(true)
      expect(r3.retried?).to be(false)
      expect(r2).to have_attributes(strict?: true, deprecated?: true, rolled_back?: true)
      expect(r3).to have_attributes(strict?: false, deprecated?: false, rolled_back?: false)
    end
  end

  describe "#tags" do
    it "returns the task's settings tags" do
      task_class.settings(tags: %w[billing])
      expect(build(CMDx::Signal.success).tags).to eq(%w[billing])
    end
  end

  describe "#xid" do
    it "delegates to the chain's xid" do
      chain = CMDx::Chain.new("req-9")
      result = described_class.new(chain, task, CMDx::Signal.success)
      expect(result.xid).to eq("req-9")
    end

    it "is nil when the chain has no xid" do
      expect(build(CMDx::Signal.success).xid).to be_nil
    end
  end

  describe "#to_h" do
    it "includes core fields for a success result" do
      chain << (result = build(CMDx::Signal.success, tid: "rid", duration: 0.1))
      hash = result.to_h

      expect(hash).to include(
        cid: chain.id,
        xid: chain.xid,
        index: 0,
        root: false,
        type: "Task",
        task: task_class,
        tid: "rid",
        state: "complete",
        status: "success",
        duration: 0.1
      )
      expect(hash).not_to have_key(:cause)
    end

    it "includes failure-specific fields for failed results" do
      sig = CMDx::Signal.failed("boom", cause: StandardError.new("x"))
      chain << (result = build(sig, rolled_back: true))
      hash = result.to_h

      expect(hash[:cause]).to be_a(StandardError)
      expect(hash).to have_key(:threw_failure)
      expect(hash).to have_key(:caused_failure)
      expect(hash[:rolled_back]).to be(true)
    end
  end

  describe "#to_s" do
    it "renders a space-separated key=value summary" do
      chain << (result = build(CMDx::Signal.success, tid: "rid"))
      expect(result.to_s).to include("tid=\"rid\"", "state=\"complete\"", "status=\"success\"")
    end
  end

  describe "#as_json" do
    it "returns the memoized to_h" do
      chain << (result = build(CMDx::Signal.success, tid: "rid"))
      expect(result.as_json).to be(result.to_h)
    end
  end

  describe "#to_json" do
    it "emits a JSON string for a success result with expected top-level keys" do
      chain << (result = build(CMDx::Signal.success, tid: "rid", duration: 0.1))

      parsed = JSON.parse(result.to_json)

      expect(parsed).to include(
        "cid" => chain.id,
        "tid" => "rid",
        "type" => "Task",
        "state" => "complete",
        "status" => "success",
        "duration" => 0.1
      )
      expect(parsed).not_to have_key("cause")
    end

    it "emits a JSON string for a failed result including failure fields" do
      sig = CMDx::Signal.failed("boom", metadata: { k: 1 })
      chain << (result = build(sig, rolled_back: true))

      parsed = JSON.parse(result.to_json)

      expect(parsed).to include(
        "state" => "interrupted",
        "status" => "failed",
        "reason" => "boom",
        "metadata" => { "k" => 1 },
        "rolled_back" => true
      )
      expect(parsed.keys).to include("threw_failure", "caused_failure")
    end
  end

  describe "pattern matching support" do
    let(:result) { build(CMDx::Signal.failed("boom", metadata: { k: 1 })) }

    describe "#deconstruct" do
      it "returns #to_h as an array of [key, value] pairs" do
        chain << result
        expect(result.deconstruct).to eq(result.to_h.to_a)
      end

      it "includes failure-specific pairs when the result failed" do
        pairs = result.deconstruct.to_h
        expect(pairs).to include(
          type: "Task",
          task: task_class,
          state: "interrupted",
          status: "failed",
          reason: "boom",
          metadata: { k: 1 },
          cause: nil
        )
        expect(pairs).to have_key(:threw_failure)
        expect(pairs).to have_key(:caused_failure)
      end

      it "supports find-pattern array matching on the pairs" do
        matched =
          case result.deconstruct
          in [*, [:status, "failed"], *]
            :found
          end

        expect(matched).to eq(:found)
      end
    end

    describe "#deconstruct_keys" do
      let(:result) do
        build(
          CMDx::Signal.failed("boom", metadata: { k: 1 }),
          strict: true,
          deprecated: true,
          retries: 3,
          rolled_back: true,
          duration: 0.25
        ).tap { |r| chain << r }
      end

      it "delegates to #to_h when keys is nil" do
        expect(result.deconstruct_keys(nil)).to eq(result.to_h)
      end

      it "returns the full pattern hash when keys is nil" do
        full = result.deconstruct_keys(nil)

        expect(full).to include(
          cid: chain.id,
          index: 0,
          root: false,
          type: "Task",
          task: task_class,
          state: "interrupted",
          status: "failed",
          reason: "boom",
          metadata: { k: 1 },
          cause: nil,
          origin: nil,
          strict: true,
          deprecated: true,
          retried: true,
          retries: 3,
          rolled_back: true,
          duration: 0.25
        )
        expect(full.keys).to include(:tid, :context, :tags, :threw_failure, :caused_failure)
      end

      it "exposes context as a live reference" do
        expect(result.deconstruct_keys(nil)[:context]).to be(task.context)
      end

      it "renders threw_failure/caused_failure as {task:, tid:} hashes" do
        full = result.deconstruct_keys(nil)
        expect(full[:threw_failure]).to eq(task: task_class, tid: nil)
        expect(full[:caused_failure]).to eq(task: task_class, tid: nil)
      end

      it "slices to the requested keys" do
        expect(result.deconstruct_keys(%i[status reason])).to eq(status: "failed", reason: "boom")
        expect(result.deconstruct_keys([])).to eq({})
      end

      it "supports hash pattern matching" do
        matched =
          case result
          in { status: "failed", reason: String => r, retries: Integer => n }
            [r, n]
          end

        expect(matched).to eq(["boom", 3])
      end

      it "omits failure-only keys for a non-failed result" do
        plain = build(CMDx::Signal.success)
        hash = plain.deconstruct_keys(nil)

        expect(hash).to include(
          strict: false,
          deprecated: false,
          retried: false,
          retries: 0,
          duration: nil
        )
        expect(hash.keys).not_to include(:cause, :origin, :threw_failure, :caused_failure, :rolled_back)
      end
    end
  end
end
