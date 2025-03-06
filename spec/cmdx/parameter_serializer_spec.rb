# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ParameterSerializer do
  subject(:simulation_task) do
    Class.new(SimulationTask) do
      required :first_name
    end
  end

  describe ".to_h" do
    it "returns serialized attributes" do
      expect(simulation_task.cmd_parameters.first.to_h).to eq(
        {
          source: :context,
          name: :first_name,
          type: :virtual,
          required: true,
          options: {},
          children: []
        }
      )
    end
  end
end
