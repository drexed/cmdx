# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ParameterRegistry do
  subject(:registry) { described_class.new }

  describe "#initialize" do
    it "creates empty registry" do
      expect(registry.registry).to eq([])
    end
  end

  describe "#dup" do
    let(:mock_parameter) { double("Parameter", dup: double("DuplicatedParameter")) }

    before do
      registry.registry << mock_parameter
    end

    it "creates new registry instance" do
      duplicated = registry.dup

      expect(duplicated).to be_a(described_class)
      expect(duplicated).not_to be(registry)
    end

    it "duplicates all parameters in registry" do
      duplicated = registry.dup

      expect(mock_parameter).to have_received(:dup)
      expect(duplicated.registry.first).to be(mock_parameter.dup)
    end

    it "maintains independence from original registry" do
      duplicated = registry.dup
      new_parameter = double("NewParameter")

      duplicated.registry << new_parameter

      expect(registry.registry).to contain_exactly(mock_parameter)
      expect(duplicated.registry).to contain_exactly(mock_parameter.dup, new_parameter)
    end
  end

  describe "#valid?" do
    context "when registry is empty" do
      it "returns true" do
        expect(registry).to be_valid
      end
    end

    context "when all parameters are valid" do
      let(:valid_parameter_one) { double("Parameter", valid?: true) }
      let(:valid_parameter_two) { double("Parameter", valid?: true) }

      before do
        registry.registry.push(valid_parameter_one, valid_parameter_two)
      end

      it "returns true" do
        expect(registry).to be_valid
      end
    end

    context "when some parameters are invalid" do
      let(:valid_parameter) { double("Parameter", valid?: true) }
      let(:invalid_parameter) { double("Parameter", valid?: false) }

      before do
        registry.registry.push(valid_parameter, invalid_parameter)
      end

      it "returns false" do
        expect(registry).not_to be_valid
      end
    end

    context "when all parameters are invalid" do
      let(:invalid_parameter_one) { double("Parameter", valid?: false) }
      let(:invalid_parameter_two) { double("Parameter", valid?: false) }

      before do
        registry.registry.push(invalid_parameter_one, invalid_parameter_two)
      end

      it "returns false" do
        expect(registry).not_to be_valid
      end
    end
  end

  describe "#validate!" do
    let(:task) { instance_double("Task") }

    context "when registry is empty" do
      it "does not raise error" do
        expect { registry.validate!(task) }.not_to raise_error
      end
    end

    context "when parameter is defined on task" do
      let(:parameter) do
        double("Parameter",
               method_name: :test_param,
               children: [])
      end

      before do
        registry.registry << parameter
        allow(task).to receive(:test_param)
      end

      it "calls parameter method on task" do
        registry.validate!(task)

        expect(task).to have_received(:test_param)
      end
    end

    context "when parameter has children" do
      let(:child_parameter) do
        double("Parameter",
               method_name: :child_param,
               children: [])
      end
      let(:parent_parameter) do
        double("Parameter",
               method_name: :parent_param,
               children: [child_parameter])
      end

      before do
        registry.registry << parent_parameter
        allow(task).to receive(:parent_param)
        allow(task).to receive(:child_param)
      end

      it "recursively validates child parameters" do
        registry.validate!(task)

        expect(task).to have_received(:parent_param)
        expect(task).to have_received(:child_param)
      end
    end

    context "when parameter has deeply nested children" do
      let(:grandchild_parameter) do
        double("Parameter",
               method_name: :grandchild_param,
               children: [])
      end
      let(:child_parameter) do
        double("Parameter",
               method_name: :child_param,
               children: [grandchild_parameter])
      end
      let(:parent_parameter) do
        double("Parameter",
               method_name: :parent_param,
               children: [child_parameter])
      end

      before do
        registry.registry << parent_parameter
        allow(task).to receive(:parent_param)
        allow(task).to receive(:child_param)
        allow(task).to receive(:grandchild_param)
      end

      it "recursively validates all nested parameters" do
        registry.validate!(task)

        expect(task).to have_received(:parent_param)
        expect(task).to have_received(:child_param)
        expect(task).to have_received(:grandchild_param)
      end
    end

    context "when multiple parameters exist" do
      let(:parameter_one) do
        double("Parameter",
               method_name: :param1,
               children: [])
      end
      let(:parameter_two) do
        double("Parameter",
               method_name: :param2,
               children: [])
      end

      before do
        registry.registry.push(parameter_one, parameter_two)
        allow(task).to receive(:param1)
        allow(task).to receive(:param2)
      end

      it "validates all parameters" do
        registry.validate!(task)

        expect(task).to have_received(:param1)
        expect(task).to have_received(:param2)
      end
    end
  end

  describe "#to_h" do
    context "when registry is empty" do
      it "returns empty array" do
        expect(registry.to_h).to eq([])
      end
    end

    context "when registry has parameters" do
      let(:parameter_one_hash) { { name: :param1, type: :string } }
      let(:parameter_two_hash) { { name: :param2, type: :integer } }
      let(:parameter_one) { double("Parameter", to_h: parameter_one_hash) }
      let(:parameter_two) { double("Parameter", to_h: parameter_two_hash) }

      before do
        registry.registry.push(parameter_one, parameter_two)
      end

      it "returns array of parameter hashes" do
        expect(registry.to_h).to eq([parameter_one_hash, parameter_two_hash])
      end

      it "calls to_h on each parameter" do
        registry.to_h

        expect(parameter_one).to have_received(:to_h)
        expect(parameter_two).to have_received(:to_h)
      end
    end
  end

  describe "#to_s" do
    context "when registry is empty" do
      it "returns empty string" do
        expect(registry.to_s).to eq("")
      end
    end

    context "when registry has parameters" do
      let(:parameter_one) { double("Parameter", to_s: "param1 (string, required)") }
      let(:parameter_two) { double("Parameter", to_s: "param2 (integer, optional)") }

      before do
        registry.registry.push(parameter_one, parameter_two)
      end

      it "returns newline-separated parameter strings" do
        expect(registry.to_s).to eq("param1 (string, required)\nparam2 (integer, optional)")
      end

      it "calls to_s on each parameter" do
        registry.to_s

        expect(parameter_one).to have_received(:to_s)
        expect(parameter_two).to have_received(:to_s)
      end
    end

    context "when registry has single parameter" do
      let(:parameter) { double("Parameter", to_s: "single_param (boolean)") }

      before do
        registry.registry << parameter
      end

      it "returns parameter string without newlines" do
        expect(registry.to_s).to eq("single_param (boolean)")
      end
    end
  end
end
