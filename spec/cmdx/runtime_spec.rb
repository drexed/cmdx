# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Runtime do
  describe ".call" do
    it "runs prepare → validate → execute → finalize for a successful task" do
      events = []
      k = Class.new(CMDx::Task) do
        required :n, :integer

        before_validation { events << :bv }
        before_execution { events << :be }
        on_success { events << :os }
        on_complete { events << :oc }
        on_executed { events << :ex }

        def work
          ctx[:out] = n * 2
        end
      end

      r = described_class.call(k, { n: 3 }, raise_on_fault: false)
      expect(r.success?).to be(true)
      expect(r.state).to eq("complete")
      expect(r.status).to eq("success")
      expect(r.context[:out]).to eq(6)
      expect(events).to eq(%i[bv be os oc ex])
    end

    it "applies signal-based fail!: halts and sets failed status" do
      k = Class.new(CMDx::Task) do
        def work
          fail!("nope", halt: true)
        end
      end
      r = described_class.call(k, {}, raise_on_fault: false)
      expect(r.failed?).to be(true)
      expect(r.state).to eq("interrupted")
      expect(r.status).to eq("failed")
    end

    it "honors non-halting fail!(halt: false) as failure signal without throw" do
      k = Class.new(CMDx::Task) do
        def work
          fail!("soft", halt: false)
        end
      end
      r = described_class.call(k, {}, raise_on_fault: false)
      expect(r.failed?).to be(true)
      expect(r.reason).to include("soft")
    end

    it "retries on configured exceptions then succeeds" do
      tries = [0]
      k = Class.new(CMDx::Task) do
        settings do |s|
          s.retry_count = 2
          s.retry_delay = 0
          s.retry_jitter = 0
          s.retry_on = [RuntimeError]
        end

        define_method(:work) do
          tries[0] += 1
          raise "boom" if tries[0] < 2

          ctx[:ok] = true
        end
      end

      r = described_class.call(k, {}, raise_on_fault: false)
      expect(r.success?).to be(true)
      expect(r.retries).to eq(1)
    end

    it "calls rollback on failure" do
      rolled = false
      k = Class.new(CMDx::Task) do
        define_method(:rollback) { rolled = true }

        def work
          fail!("x", halt: true)
        end
      end
      r = described_class.call(k, {}, raise_on_fault: false)
      expect(r.failed?).to be(true)
      expect(rolled).to be(true)
    end

    it "invokes on_failed when execution fails" do
      seen = []
      k = Class.new(CMDx::Task) do
        on_failed { seen << :failed }

        def work
          fail!("z", halt: true)
        end
      end
      described_class.call(k, {}, raise_on_fault: false)
      expect(seen).to eq([:failed])
    end

    it "fails when declared returns are missing from context" do
      k = Class.new(CMDx::Task) do
        returns :required_key
        def work; end
      end
      r = described_class.call(k, {}, raise_on_fault: false)
      expect(r.failed?).to be(true)
      expect(r.errors.for?(:required_key)).to be(true)
    end

    it "deprecation_check! raises DeprecationError when deprecate mode is :restrict" do
      k = Class.new(CMDx::Task) do
        settings { |s| s.deprecate = { mode: :restrict } }
        def work; end
      end
      rt = described_class.new(k, {})
      expect { rt.send(:deprecation_check!) }.to raise_error(CMDx::DeprecationError)
    end
  end
end
