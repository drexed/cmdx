# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ChainInspector do
  include_context "with simulation task setup"

  let(:inspected_result) { result.chain.to_s }
  let(:expected_string_output) do
    <<~TEXT

      chain: 018c2b95-b764-7615-a924-cc5b910ed1e5
      =================================================================

      {index: 0,
       type: "Task",
       class: "SimulationTask",
       id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
       tags: [],
       state: "complete",
       status: "success",
       outcome: "success",
       metadata: {},
       runtime: 0}

      =================================================================
      state: complete | status: success | outcome: success | runtime: 0

    TEXT
  end

  it_behaves_like "an inspector"
end
