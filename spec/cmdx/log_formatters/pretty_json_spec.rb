# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::PrettyJson do
  describe ".call" do
    it "returns PrettyJson formatted log line" do
      local_io = LogFormatterHelpers.simulation_output(described_class, :success)

      expect(local_io).to match_log(<<~LINE)
        {
          "index": 0,
          "run_id": "018c2b95-b764-7615-a924-cc5b910ed1e5",
          "type": "Task",
          "class": "SimulationTask",
          "id": "018c2b95-b764-7615-a924-cc5b910ed1e5",
          "state": "complete",
          "status": "success",
          "outcome": "success",
          "metadata": {},
          "runtime": 0,
          "tags": [],
          "pid": 3784
        }
      LINE
    end
  end
end
