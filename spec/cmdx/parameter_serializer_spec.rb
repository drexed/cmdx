# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ParameterSerializer do
  subject(:simulation_task) do
    Class.new(SimulationTask) do
      required :first_name
    end
  end

  let(:serialized_result) { simulation_task.cmd_parameters.first.to_h }
  let(:expected_serialized_attributes) do
    {
      source: :context,
      name: :first_name,
      type: :virtual,
      required: true,
      options: {},
      children: []
    }
  end

  it_behaves_like "a serializer"
end
