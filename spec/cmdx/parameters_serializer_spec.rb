# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ParametersSerializer do
  describe ".call" do
    let(:parameter_registry) { CMDx::ParameterRegistry.new }

    context "when parameters collection is empty" do
      it "returns empty array" do
        result = described_class.call(parameter_registry)

        expect(result).to eq([])
      end
    end

    context "when parameters collection has single parameter" do
      let(:parameter_hash) { { source: :context, name: :user_id, type: :integer, required: true, options: {}, children: [] } }
      let(:parameter) { mock_parameter(to_h: parameter_hash) }

      before do
        parameter_registry.registry << parameter
      end

      it "returns array with single parameter hash" do
        result = described_class.call(parameter_registry)

        expect(result).to eq([parameter_hash])
      end

      it "calls to_h on the parameter" do
        expect(parameter).to receive(:to_h)

        described_class.call(parameter_registry)
      end
    end

    context "when parameters collection has multiple parameters" do
      let(:first_parameter_hash) { { source: :context, name: :user_id, type: :integer, required: true, options: {}, children: [] } }
      let(:second_parameter_hash) { { source: :context, name: :email, type: :string, required: false, options: {}, children: [] } }
      let(:first_parameter) { mock_parameter(to_h: first_parameter_hash) }
      let(:second_parameter) { mock_parameter(to_h: second_parameter_hash) }

      before do
        parameter_registry.registry << first_parameter
        parameter_registry.registry << second_parameter
      end

      it "returns array with all parameter hashes" do
        result = described_class.call(parameter_registry)

        expect(result).to eq([first_parameter_hash, second_parameter_hash])
      end

      it "calls to_h on all parameters" do
        expect(first_parameter).to receive(:to_h)
        expect(second_parameter).to receive(:to_h)

        described_class.call(parameter_registry)
      end

      it "maintains parameter order in output" do
        result = described_class.call(parameter_registry)

        expect(result.first[:name]).to eq(:user_id)
        expect(result.last[:name]).to eq(:email)
      end
    end

    context "when parameters collection has many parameters" do
      before do
        5.times do |i|
          param_hash = { source: :context, name: :"param#{i}", type: :string, required: false, options: {}, children: [] }
          param = mock_parameter(to_h: param_hash)
          parameter_registry.registry << param
        end
      end

      it "handles large collections efficiently" do
        result = described_class.call(parameter_registry)

        expect(result.size).to eq(5)
      end

      it "includes all parameters in output" do
        result = described_class.call(parameter_registry)

        5.times do |i|
          expect(result[i][:name]).to eq(:"param#{i}")
        end
      end
    end

    context "when parameters have different hash representations" do
      let(:simple_parameter_hash) { { name: :id, type: :integer } }
      let(:complex_parameter_hash) do
        {
          source: :context,
          name: :email,
          type: :string,
          required: true,
          options: { format: { with: /email/ } },
          children: []
        }
      end
      let(:minimal_parameter_hash) { { name: :flag } }
      let(:simple_parameter) { mock_parameter(to_h: simple_parameter_hash) }
      let(:complex_parameter) { mock_parameter(to_h: complex_parameter_hash) }
      let(:minimal_parameter) { mock_parameter(to_h: minimal_parameter_hash) }

      before do
        parameter_registry.registry << simple_parameter
        parameter_registry.registry << complex_parameter
        parameter_registry.registry << minimal_parameter
      end

      it "preserves individual parameter hash structures" do
        result = described_class.call(parameter_registry)

        expect(result[0]).to eq(simple_parameter_hash)
        expect(result[1]).to eq(complex_parameter_hash)
        expect(result[2]).to eq(minimal_parameter_hash)
      end

      it "maintains all hash keys and values" do
        result = described_class.call(parameter_registry)

        expect(result[1]).to include(
          source: :context,
          name: :email,
          type: :string,
          required: true,
          options: { format: { with: /email/ } },
          children: []
        )
      end
    end

    context "when parameters return nested hash structures" do
      let(:parent_parameter_hash) do
        {
          source: :context,
          name: :address,
          type: :virtual,
          required: false,
          options: {},
          children: [
            { source: :address, name: :street, type: :virtual, required: true, options: {}, children: [] },
            { source: :address, name: :city, type: :virtual, required: true, options: {}, children: [] }
          ]
        }
      end
      let(:parent_parameter) { mock_parameter(to_h: parent_parameter_hash) }

      before do
        parameter_registry.registry << parent_parameter
      end

      it "preserves nested structures in hash" do
        result = described_class.call(parameter_registry)

        expect(result.first[:children]).to be_an(Array)
        expect(result.first[:children].size).to eq(2)
        expect(result.first[:children].first[:name]).to eq(:street)
        expect(result.first[:children].last[:name]).to eq(:city)
      end
    end

    context "when parameters return empty hash representations" do
      let(:empty_parameter) { mock_parameter(to_h: {}) }
      let(:normal_parameter_hash) { { name: :user_id, type: :integer } }
      let(:normal_parameter) { mock_parameter(to_h: normal_parameter_hash) }

      before do
        parameter_registry.registry << empty_parameter
        parameter_registry.registry << normal_parameter
      end

      it "includes empty hashes in output" do
        result = described_class.call(parameter_registry)

        expect(result.size).to eq(2)
        expect(result[0]).to eq({})
        expect(result[1]).to eq(normal_parameter_hash)
      end
    end

    context "when dealing with parameter ordering" do
      let(:first_parameter) { mock_parameter(to_h: { name: :first, order: 1 }) }
      let(:second_parameter) { mock_parameter(to_h: { name: :second, order: 2 }) }
      let(:third_parameter) { mock_parameter(to_h: { name: :third, order: 3 }) }

      before do
        parameter_registry.registry << first_parameter
        parameter_registry.registry << second_parameter
        parameter_registry.registry << third_parameter
      end

      it "preserves insertion order" do
        result = described_class.call(parameter_registry)

        expect(result.map { |hash| hash[:name] }).to eq(%i[first second third])
        expect(result.map { |hash| hash[:order] }).to eq([1, 2, 3])
      end
    end

    context "when parameter registry is modified after creation" do
      let(:initial_parameter) { mock_parameter(to_h: { name: :initial }) }
      let(:added_parameter) { mock_parameter(to_h: { name: :added }) }

      before do
        parameter_registry.registry << initial_parameter
      end

      it "reflects current state of registry" do
        parameter_registry.registry << added_parameter

        result = described_class.call(parameter_registry)

        expect(result.size).to eq(2)
        expect(result.first[:name]).to eq(:initial)
        expect(result.last[:name]).to eq(:added)
      end
    end

    context "when parameters contain various data types in hashes" do
      let(:complex_parameter_hash) do
        {
          name: :complex_param,
          type: :string,
          required: true,
          options: {
            format: { with: /^[a-z]+$/ },
            length: { within: 1..50 },
            presence: true
          },
          metadata: {
            created_at: Time.now,
            tags: %i[important user_input],
            config: { env: "production", debug: false }
          }
        }
      end
      let(:complex_parameter) { mock_parameter(to_h: complex_parameter_hash) }

      before do
        parameter_registry.registry << complex_parameter
      end

      it "preserves all data types in hash" do
        result = described_class.call(parameter_registry)

        hash = result.first
        expect(hash[:name]).to be_a(Symbol)
        expect(hash[:required]).to be_a(TrueClass)
        expect(hash[:options][:format][:with]).to be_a(Regexp)
        expect(hash[:options][:length][:within]).to be_a(Range)
        expect(hash[:options][:presence]).to be(true)
        expect(hash[:metadata][:tags]).to be_an(Array)
      end
    end

    context "when parameters raise exceptions during to_h" do
      let(:failing_parameter) { mock_parameter }
      let(:normal_parameter) { mock_parameter(to_h: { name: :normal }) }

      before do
        parameter_registry.registry << failing_parameter
        parameter_registry.registry << normal_parameter
        allow(failing_parameter).to receive(:to_h).and_raise(StandardError, "to_h failed")
      end

      it "allows exceptions to propagate" do
        expect { described_class.call(parameter_registry) }.to raise_error(StandardError, "to_h failed")
      end
    end

    context "when parameters return nil from to_h" do
      let(:nil_parameter) { mock_parameter(to_h: nil) }
      let(:normal_parameter) { mock_parameter(to_h: { name: :normal }) }

      before do
        parameter_registry.registry << nil_parameter
        parameter_registry.registry << normal_parameter
      end

      it "includes nil values in output array" do
        result = described_class.call(parameter_registry)

        expect(result.size).to eq(2)
        expect(result[0]).to be_nil
        expect(result[1]).to eq({ name: :normal })
      end
    end
  end
end
