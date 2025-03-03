# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ParameterInspector do
  subject(:simulation_task) do
    Class.new(SimulationTask) do
      required :first_name
    end
  end

  describe ".to_s" do
    it "returns stringified attribute" do
      expect(simulation_task.cmd_parameters.first.to_s).to eq(<<~TXT.gsub("\n", " \n").chomp)
        Parameter: name=first_name type=virtual source=context required=true options={}
      TXT
    end
  end

end
