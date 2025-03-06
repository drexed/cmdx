# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::KeyValue do
  include LogFormatterHelpers

  describe ".call" do
    it "returns Key Value formatted log line" do
      local_io = log_formatter_simulation(described_class, :success)

      expect(local_io).to match_log(<<~LINE.tr("\n", " "))
        index=0
        run_id=018c2b95-b764-7615-a924-cc5b910ed1e5
        type=Task
        class=SimulationTask
        id=018c2b95-b764-7615-a924-cc5b910ed1e5
        state=complete
        status=success
        outcome=success
        metadata={}
        runtime=0
        tags=[]
        pid=3784
      LINE
    end
  end
end
