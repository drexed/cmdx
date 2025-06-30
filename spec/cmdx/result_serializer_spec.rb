# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ResultSerializer do
  include_context "with simulation task setup"

  let(:expected_success_serialized_attributes) do
    {
      index: 0,
      chain_id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
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
  end

  let(:expected_failure_serialized_attributes) do
    {
      index: 0,
      chain_id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
      type: "Task",
      class: "SimulationTask",
      id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
      outcome: CMDx::Result::INTERRUPTED,
      state: CMDx::Result::INTERRUPTED,
      status: CMDx::Result::FAILED,
      metadata: {},
      runtime: 0,
      tags: [],
      caused_failure: {
        class: "SimulationTask",
        id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
        index: 2,
        metadata: {},
        outcome: CMDx::Result::FAILED,
        runtime: 0,
        chain_id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
        state: CMDx::Result::INTERRUPTED,
        status: CMDx::Result::FAILED,
        tags: [],
        type: "Task"
      },
      threw_failure: {
        class: "SimulationTask",
        id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
        index: 1,
        metadata: {},
        outcome: CMDx::Result::INTERRUPTED,
        runtime: 0,
        chain_id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
        state: CMDx::Result::INTERRUPTED,
        status: CMDx::Result::FAILED,
        tags: [],
        type: "Task"
      }
    }
  end

  it_behaves_like "a result serializer"
end
