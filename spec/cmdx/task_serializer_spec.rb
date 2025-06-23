# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::TaskSerializer do
  include_context "simulation task setup"

  let(:serialized_result) { described_class.call(result.task) }
  let(:expected_serialized_attributes) do
    {
      index: 0,
      run_id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
      type: "Task",
      class: "SimulationTask",
      id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
      tags: []
    }
  end

  it_behaves_like "a serializer"
end
