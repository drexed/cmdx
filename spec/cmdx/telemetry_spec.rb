# frozen_string_literal: true

RSpec.describe CMDx::Telemetry do
  let(:output) { StringIO.new }
  let(:logger) { Logger.new(output) }

  describe "#emit" do
    it "logs the event" do
      telemetry = described_class.new(logger:)
      telemetry.emit(:task_completed, task: "MyTask")
      expect(output.string).to include("task_completed")
    end

    it "applies redaction" do
      redact = ->(payload) { payload.except(:secret) }
      telemetry = described_class.new(logger:, redact:)
      telemetry.emit(:event, secret: "hidden", safe: "ok")
      expect(output.string).to include("safe")
      expect(output.string).not_to include("hidden")
    end
  end
end
