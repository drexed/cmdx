# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ParametersInspector do
  describe ".call" do
    let(:parameter_registry) { CMDx::ParameterRegistry.new }

    context "when parameters collection is empty" do
      it "returns empty string" do
        result = described_class.call(parameter_registry)

        expect(result).to eq("")
      end
    end

    context "when parameters collection has single parameter" do
      let(:parameter) { mock_parameter(to_s: "Parameter: name=user_id type=integer source=context required=true options={}") }

      before do
        parameter_registry << parameter
      end

      it "returns single parameter string representation" do
        result = described_class.call(parameter_registry)

        expect(result).to eq("Parameter: name=user_id type=integer source=context required=true options={}")
      end

      it "calls to_s on the parameter" do
        expect(parameter).to receive(:to_s)

        described_class.call(parameter_registry)
      end
    end

    context "when parameters collection has multiple parameters" do
      let(:first_parameter) { mock_parameter(to_s: "Parameter: name=user_id type=integer source=context required=true options={}") }
      let(:second_parameter) { mock_parameter(to_s: "Parameter: name=email type=string source=context required=false options={}") }

      before do
        parameter_registry << first_parameter
        parameter_registry << second_parameter
      end

      it "returns all parameter string representations joined by newlines" do
        result = described_class.call(parameter_registry)

        expected_result = "Parameter: name=user_id type=integer source=context required=true options={}\n" \
                          "Parameter: name=email type=string source=context required=false options={}"
        expect(result).to eq(expected_result)
      end

      it "calls to_s on all parameters" do
        expect(first_parameter).to receive(:to_s)
        expect(second_parameter).to receive(:to_s)

        described_class.call(parameter_registry)
      end

      it "maintains parameter order in output" do
        result = described_class.call(parameter_registry)

        lines = result.split("\n")
        expect(lines.first).to include("user_id")
        expect(lines.last).to include("email")
      end
    end

    context "when parameters collection has many parameters" do
      before do
        5.times do |i|
          param = mock_parameter(to_s: "Parameter: name=param#{i} type=string source=context required=false options={}")
          parameter_registry << param
        end
      end

      it "handles large collections efficiently" do
        result = described_class.call(parameter_registry)

        lines = result.split("\n")
        expect(lines.size).to eq(5)
      end

      it "includes all parameters in output" do
        result = described_class.call(parameter_registry)

        5.times do |i|
          expect(result).to include("param#{i}")
        end
      end
    end

    context "when parameters have different string representations" do
      let(:simple_parameter) { mock_parameter(to_s: "Parameter: name=id type=integer") }
      let(:complex_parameter) { mock_parameter(to_s: "Parameter: name=email type=string source=context required=true options={format: {with: /email/}}") }
      let(:minimal_parameter) { mock_parameter(to_s: "Parameter: name=flag") }

      before do
        parameter_registry << simple_parameter
        parameter_registry << complex_parameter
        parameter_registry << minimal_parameter
      end

      it "preserves individual parameter formatting" do
        result = described_class.call(parameter_registry)

        expect(result).to include("Parameter: name=id type=integer")
        expect(result).to include("Parameter: name=email type=string source=context required=true options={format: {with: /email/}}")
        expect(result).to include("Parameter: name=flag")
      end

      it "separates different parameters with newlines" do
        result = described_class.call(parameter_registry)

        lines = result.split("\n")
        expect(lines.size).to eq(3)
        expect(lines[0]).to eq("Parameter: name=id type=integer")
        expect(lines[1]).to eq("Parameter: name=email type=string source=context required=true options={format: {with: /email/}}")
        expect(lines[2]).to eq("Parameter: name=flag")
      end
    end

    context "when parameters return empty string representations" do
      let(:empty_parameter) { mock_parameter(to_s: "") }
      let(:normal_parameter) { mock_parameter(to_s: "Parameter: name=user_id type=integer") }

      before do
        parameter_registry << empty_parameter
        parameter_registry << normal_parameter
      end

      it "includes empty lines in output" do
        result = described_class.call(parameter_registry)

        lines = result.split("\n", -1) # -1 to preserve empty strings
        expect(lines.size).to eq(2)
        expect(lines[0]).to eq("")
        expect(lines[1]).to eq("Parameter: name=user_id type=integer")
      end
    end

    context "when parameters contain newlines in their string representations" do
      let(:multiline_parameter) { mock_parameter(to_s: "Parameter: name=complex\nwith multiple lines") }
      let(:normal_parameter) { mock_parameter(to_s: "Parameter: name=simple") }

      before do
        parameter_registry << multiline_parameter
        parameter_registry << normal_parameter
      end

      it "preserves newlines within parameter representations" do
        result = described_class.call(parameter_registry)

        expect(result).to include("Parameter: name=complex\nwith multiple lines")
        expect(result).to include("Parameter: name=simple")
      end

      it "maintains correct separation between parameters" do
        result = described_class.call(parameter_registry)

        expected_result = "Parameter: name=complex\nwith multiple lines\nParameter: name=simple"
        expect(result).to eq(expected_result)
      end
    end

    context "when dealing with parameter ordering" do
      let(:first_parameter) { mock_parameter(to_s: "First") }
      let(:second_parameter) { mock_parameter(to_s: "Second") }
      let(:third_parameter) { mock_parameter(to_s: "Third") }

      before do
        parameter_registry << first_parameter
        parameter_registry << second_parameter
        parameter_registry << third_parameter
      end

      it "preserves insertion order" do
        result = described_class.call(parameter_registry)

        lines = result.split("\n")
        expect(lines).to eq(%w[First Second Third])
      end
    end

    context "when parameter registry is modified after creation" do
      let(:initial_parameter) { mock_parameter(to_s: "Initial parameter") }
      let(:added_parameter) { mock_parameter(to_s: "Added parameter") }

      before do
        parameter_registry << initial_parameter
      end

      it "reflects current state of registry" do
        parameter_registry << added_parameter

        result = described_class.call(parameter_registry)

        expect(result).to include("Initial parameter")
        expect(result).to include("Added parameter")
      end
    end

    context "when parameters raise exceptions during to_s" do
      let(:failing_parameter) { mock_parameter }
      let(:normal_parameter) { mock_parameter(to_s: "Normal parameter") }

      before do
        parameter_registry << failing_parameter
        parameter_registry << normal_parameter
        allow(failing_parameter).to receive(:to_s).and_raise(StandardError, "to_s failed")
      end

      it "allows exceptions to propagate" do
        expect { described_class.call(parameter_registry) }.to raise_error(StandardError, "to_s failed")
      end
    end
  end
end
