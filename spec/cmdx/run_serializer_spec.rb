# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::RunSerializer do
  include_context "with simulation task setup"

  let(:serialized_result) { result.run.to_h }
  let(:expected_serialized_attributes) do
    {
      id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
      state: CMDx::Result::COMPLETE,
      status: CMDx::Result::SUCCESS,
      outcome: CMDx::Result::SUCCESS,
      runtime: 0,
      results: [
        {
          index: 0,
          run_id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
          type: "Task",
          class: "SimulationTask",
          id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
          outcome: CMDx::Result::SUCCESS,
          state: CMDx::Result::COMPLETE,
          status: CMDx::Result::SUCCESS,
          metadata: {},
          runtime: 0,
          tags: []
        }
      ]
    }
  end

  it_behaves_like "a serializer"
end
