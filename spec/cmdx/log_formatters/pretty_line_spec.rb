# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::PrettyLine do
  describe ".call" do
    it "returns PrettyLine formatted log line" do
      local_io = LogFormatterHelpers.simulation_output(described_class, :success)

      expect(local_io).to match_log(<<~LINE.tr("\n", " "))
        #{CMDx::LoggerAnsi.call('I')}, [2022-07-17T18:43:15.000000 #3784] #{CMDx::LoggerAnsi.call('INFO')} -- SimulationTask:
        index=0
        run_id=018c2b95-b764-7615-a924-cc5b910ed1e5
        type=Task
        task=SimulationTask
        id=018c2b95-b764-7615-a924-cc5b910ed1e5
        tags=[]
        state=#{CMDx::ResultAnsi.call('complete')}
        status=#{CMDx::ResultAnsi.call('success')}
        outcome=#{CMDx::ResultAnsi.call('success')}
        metadata={}
        runtime=0
        origin=CMDx
      LINE
    end
  end
end
