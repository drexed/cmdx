# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::PrettyKeyValue do
  let(:expected_success_output) do
    <<~LINE.tr("\n", " ")
      index=0
      chain_id=018c2b95-b764-7615-a924-cc5b910ed1e5
      type=Task
      class=SimulationTask
      id=018c2b95-b764-7615-a924-cc5b910ed1e5
      tags=[]
      state=#{CMDx::ResultAnsi.call('complete')}
      status=#{CMDx::ResultAnsi.call('success')}
      outcome=#{CMDx::ResultAnsi.call('success')}
      metadata={}
      runtime=0
      origin=CMDx
      severity=INFO
      pid=3784
      timestamp=2022-07-17T18:43:15.000000
    LINE
  end

  it_behaves_like "a simple log formatter"
end
