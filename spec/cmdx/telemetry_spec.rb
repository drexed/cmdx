# frozen_string_literal: true

RSpec.describe CMDx::Telemetry do
  subject(:telemetry) { described_class.new }

  describe "#initialize" do
    it "starts with an empty registry" do
      expect(telemetry).to be_empty
      expect(telemetry.registry).to eq({})
    end
  end

  describe "Event" do
    it "carries cid, xid, root, type, task, tid, name, payload, timestamp" do
      event = described_class::Event.new(
        cid: "cid", xid: "req-1", root: true, type: "Task", task: Object,
        tid: "tid", name: :task_started, payload: {}, timestamp: Time.now.utc
      )

      expect(event).to have_attributes(cid: "cid", xid: "req-1", root: true, tid: "tid")
    end
  end

  describe "#initialize_copy" do
    it "deep-dups each event's subscriber list" do
      sub = ->(_p) {}
      telemetry.subscribe(:task_started, sub)

      copy = telemetry.dup
      copy.subscribe(:task_started, ->(_p) {})

      expect(telemetry.registry[:task_started]).to eq([sub])
      expect(copy.registry[:task_started].size).to eq(2)
    end
  end

  describe "#subscribe" do
    let(:sub) { ->(_p) {} }

    it "appends the subscriber and returns self" do
      expect(telemetry.subscribe(:task_started, sub)).to be(telemetry)
      expect(telemetry.registry[:task_started]).to eq([sub])
    end

    it "accepts a block" do
      telemetry.subscribe(:task_started) { |_p| :ok }
      expect(telemetry.registry[:task_started].size).to eq(1)
    end

    it "raises when both callable and block are given" do
      expect { telemetry.subscribe(:task_started, sub) { |_p| :ok } }
        .to raise_error(ArgumentError, /subscriber: provide either a callable or a block, not both/)
    end

    it "raises when the subscriber does not respond to call" do
      expect { telemetry.subscribe(:task_started, "not callable") }
        .to raise_error(ArgumentError, /subscriber must respond to #call/)
    end

    it "raises when the event is unknown" do
      expect { telemetry.subscribe(:bogus, sub) }
        .to raise_error(ArgumentError, /unknown telemetry event :bogus, must be one of/)
    end
  end

  describe "#unsubscribe" do
    let(:sub1) { ->(_p) {} }
    let(:sub2) { ->(_p) {} }

    it "removes the callable and returns self" do
      telemetry.subscribe(:task_started, sub1)
      telemetry.subscribe(:task_started, sub2)

      expect(telemetry.unsubscribe(:task_started, sub1)).to be(telemetry)
      expect(telemetry.registry[:task_started]).to eq([sub2])
    end

    it "removes the event key when the last subscriber goes away" do
      telemetry.subscribe(:task_started, sub1)
      telemetry.unsubscribe(:task_started, sub1)

      expect(telemetry.registry).not_to have_key(:task_started)
      expect(telemetry).to be_empty
    end

    it "is a no-op when the event has no subscribers" do
      expect(telemetry.unsubscribe(:task_started, sub1)).to be(telemetry)
    end

    it "raises for an unknown event" do
      expect { telemetry.unsubscribe(:bogus, sub1) }
        .to raise_error(CMDx::UnknownEntryError, /unknown telemetry event :bogus/)
    end
  end

  describe "#subscribed?" do
    it "is true when at least one subscriber exists" do
      telemetry.subscribe(:task_started, ->(_p) {})
      expect(telemetry.subscribed?(:task_started)).to be(true)
      expect(telemetry.subscribed?(:task_executed)).to be(false)
    end
  end

  describe "#lookup" do
    let(:sub) { ->(_p) {} }

    it "returns the subscriber list for a registered event" do
      telemetry.subscribe(:task_started, sub)
      expect(telemetry.lookup(:task_started)).to eq([sub])
    end

    it "raises when the event has no subscribers" do
      expect { telemetry.lookup(:task_started) }
        .to raise_error(CMDx::UnknownEntryError, /unknown telemetry event :task_started; registered: \[\]/)
    end

    it "lists currently registered events in the error message" do
      telemetry.subscribe(:task_executed, sub)
      expect { telemetry.lookup(:task_started) }
        .to raise_error(CMDx::UnknownEntryError, /registered: \[:task_executed\]/)
    end
  end

  describe "#size and #count" do
    before do
      telemetry.subscribe(:task_started, ->(_p) {})
      telemetry.subscribe(:task_started, ->(_p) {})
      telemetry.subscribe(:task_executed, ->(_p) {})
    end

    it "size returns distinct event count" do
      expect(telemetry.size).to eq(2)
    end

    it "count returns total subscribers across events" do
      expect(telemetry.count).to eq(3)
    end
  end

  describe "#emit" do
    it "is a no-op when the registry is empty" do
      expect { telemetry.emit(:task_started, :payload) }.not_to raise_error
    end

    it "raises when the registry is non-empty but the event is unregistered" do
      telemetry.subscribe(:task_executed, ->(_p) {})
      expect { telemetry.emit(:task_started, :payload) }
        .to raise_error(CMDx::UnknownEntryError, /unknown telemetry event :task_started/)
    end

    it "is a no-op when subscribers were unsubscribed leaving an empty list" do
      sub = ->(_p) {}
      telemetry.subscribe(:task_started, sub)
      telemetry.subscribe(:task_executed, ->(_p) {})
      telemetry.registry[:task_started].clear

      expect { telemetry.emit(:task_started, :payload) }.not_to raise_error
    end

    it "calls each subscriber with the payload, in order" do
      received = []
      telemetry.subscribe(:task_started, ->(p) { received << [:a, p] })
      telemetry.subscribe(:task_started, ->(p) { received << [:b, p] })

      telemetry.emit(:task_started, :payload)
      expect(received).to eq([%i[a payload], %i[b payload]])
    end

    it "only fires subscribers for the given event" do
      received = []
      telemetry.subscribe(:task_started, ->(p) { received << p })
      telemetry.subscribe(:task_executed, ->(p) { received << [:exec, p] })

      telemetry.emit(:task_started, 42)

      expect(received).to eq([42])
    end
  end
end
