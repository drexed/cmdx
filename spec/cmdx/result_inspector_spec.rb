# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ResultInspector do
  include_context "simulation task setup"

  let(:expected_success_output) do
    <<~TEXT
      SimulationTask:
      type=Task
      index=0
      id=018c2b95-b764-7615-a924-cc5b910ed1e5
      state=complete
      status=success
      outcome=success
      metadata={}
      tags=[]
      runtime=0
    TEXT
  end

  let(:expected_failure_output) do
    <<~TEXT
      SimulationTask:
      type=Task
      index=0
      id=018c2b95-b764-7615-a924-cc5b910ed1e5
      state=interrupted
      status=failed
      outcome=interrupted
      metadata={}
      tags=[]
      runtime=0
      caused_failure=<[2] SimulationTask: 018c2b95-b764-7615-a924-cc5b910ed1e5>
      threw_failure=<[1] SimulationTask: 018c2b95-b764-7615-a924-cc5b910ed1e5>
    TEXT
  end

  it_behaves_like "a result inspector"
end
