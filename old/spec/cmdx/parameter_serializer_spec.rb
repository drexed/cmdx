# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ParameterSerializer do
  describe ".call" do
    let(:task_class) { create_task_class(name: "TestTask") }

    context "with basic parameter" do
      let(:parameter) do
        CMDx::Parameter.new(:user_name, klass: task_class, type: :string, required: true)
      end

      it "serializes parameter with all required fields" do
        result = described_class.call(parameter)

        expect(result).to be_a(Hash)
        expect(result[:source]).to eq(:context)
        expect(result[:name]).to eq(:user_name)
        expect(result[:type]).to eq(:string)
        expect(result[:required]).to be(true)
        expect(result[:options]).to eq({})
        expect(result[:children]).to eq([])
      end
    end

    context "with optional parameter" do
      let(:parameter) do
        CMDx::Parameter.new(:email, klass: task_class, type: :string, required: false)
      end

      it "serializes optional parameter correctly" do
        result = described_class.call(parameter)

        expect(result[:required]).to be(false)
        expect(result[:name]).to eq(:email)
        expect(result[:type]).to eq(:string)
      end
    end

    context "with parameter options" do
      let(:parameter) do
        CMDx::Parameter.new(
          :age,
          klass: task_class,
          type: :integer,
          required: true,
          default: 18,
          numeric: { min: 0, max: 120 }
        )
      end

      it "includes parameter options in serialization" do
        result = described_class.call(parameter)

        expect(result[:options]).to include(
          default: 18,
          numeric: { min: 0, max: 120 }
        )
      end
    end

    context "with custom source parameter" do
      let(:parameter) do
        CMDx::Parameter.new(
          :company_name,
          klass: task_class,
          type: :string,
          source: :user
        )
      end

      it "serializes parameter with custom source" do
        result = described_class.call(parameter)

        expect(result[:source]).to eq(:user)
        expect(result[:name]).to eq(:company_name)
      end
    end

    context "with nested parameters" do
      let(:parameter) do
        CMDx::Parameter.new(:user, klass: task_class, type: :hash) do
          required :name, type: :string
          optional :age, type: :integer
        end
      end

      it "serializes nested parameters with children" do
        result = described_class.call(parameter)

        expect(result[:children].size).to eq(2)
        expect(result[:children]).to all(be_a(Hash))

        name_child = result[:children].find { |c| c[:name] == :name }
        expect(name_child[:required]).to be(true)
        expect(name_child[:type]).to eq(:string)
        expect(name_child[:source]).to eq(:user)

        age_child = result[:children].find { |c| c[:name] == :age }
        expect(age_child[:required]).to be(false)
        expect(age_child[:type]).to eq(:integer)
        expect(age_child[:source]).to eq(:user)
      end
    end

    context "with deeply nested parameters" do
      let(:parameter) do
        CMDx::Parameter.new(:user, klass: task_class, type: :hash) do
          required :profile, type: :hash do
            required :name, type: :string
            optional :preferences, type: :hash do
              optional :theme, type: :string
            end
          end
        end
      end

      it "serializes multi-level nested parameters" do
        result = described_class.call(parameter)

        expect(result[:children].size).to eq(1)
        profile_child = result[:children].first
        expect(profile_child[:name]).to eq(:profile)

        expect(profile_child[:children].size).to eq(2)
        preferences_child = profile_child[:children].find { |c| c[:name] == :preferences }
        expect(preferences_child[:children].size).to eq(1)
        expect(preferences_child[:children].first[:name]).to eq(:theme)
      end
    end

    context "with virtual type parameter" do
      let(:parameter) do
        CMDx::Parameter.new(:metadata, klass: task_class)
      end

      it "serializes virtual type parameter" do
        result = described_class.call(parameter)

        expect(result[:type]).to eq(:virtual)
        expect(result[:required]).to be(false)
      end
    end

    context "with multiple type parameter" do
      let(:parameter) do
        CMDx::Parameter.new(
          :value,
          klass: task_class,
          type: %i[string integer],
          required: true
        )
      end

      it "serializes parameter with multiple types" do
        result = described_class.call(parameter)

        expect(result[:type]).to eq(%i[string integer])
      end
    end

    context "with empty children array" do
      let(:parameter) do
        CMDx::Parameter.new(:empty_parent, klass: task_class, type: :hash)
      end

      it "serializes parameter with empty children array" do
        result = described_class.call(parameter)

        expect(result[:children]).to eq([])
      end
    end

    context "with parameter containing nil options" do
      let(:parameter) do
        param = CMDx::Parameter.new(:test, klass: task_class, type: :string)
        allow(param).to receive(:options).and_return(nil)
        param
      end

      it "includes nil options in serialization" do
        result = described_class.call(parameter)

        expect(result[:options]).to be_nil
      end
    end
  end
end
