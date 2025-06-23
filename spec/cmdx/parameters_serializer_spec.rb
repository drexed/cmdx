# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ParametersSerializer do
  subject(:simulation_task) do
    Class.new(SimulationTask) do
      required :first_name, :last_name
      optional :address, type: :hash do
        required :city
        optional :state, default: "USA", desc: "Alpha-2"
      end
    end
  end

  let(:serialized_result) { simulation_task.cmd_parameters.to_h }
  let(:expected_serialized_attributes) do
    [
      {
        source: :context,
        name: :first_name,
        type: :virtual,
        required: true,
        options: {},
        children: []
      },
      {
        source: :context,
        name: :last_name,
        type: :virtual,
        required: true,
        options: {},
        children: []
      },
      {
        source: :context,
        name: :address,
        type: :hash,
        required: false,
        options: {},
        children: [
          {
            source: :address,
            name: :city,
            type: :virtual,
            required: true,
            options: {},
            children: []
          },
          {
            source: :address,
            name: :state,
            type: :virtual,
            required: false,
            options: { default: "USA", desc: "Alpha-2" },
            children: []
          }
        ]
      }
    ]
  end

  it_behaves_like "a serializer"
end
