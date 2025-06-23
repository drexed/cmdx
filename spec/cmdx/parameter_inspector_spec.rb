# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ParameterInspector do
  subject(:simulation_task) do
    Class.new(SimulationTask) do
      required :first_name
    end
  end

  let(:inspected_result) { simulation_task.cmd_parameters.first.to_s }
  let(:expected_string_output) do
    <<~TXT.gsub("\n", " \n").chomp
      Parameter: name=first_name type=virtual source=context required=true options={}
    TXT
  end

  it_behaves_like "an inspector"
end
