# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ParameterInspector do
  describe ".call" do
    context "with basic parameter" do
      let(:parameter) do
        {
          name: :user_name,
          type: :string,
          source: :user,
          required: true,
          options: { min: 3 },
          children: []
        }
      end

      it "formats parameter with all keys in correct order" do
        result = described_class.call(parameter)

        expect(result).to eq("Parameter: name=user_name type=string source=user required=true options={min: 3} ")
      end
    end

    context "with parameter containing children" do
      let(:parameter) do
        {
          name: :user,
          type: :hash,
          source: :context,
          required: false,
          options: {},
          children: [
            {
              name: :name,
              type: :string,
              source: :user,
              required: true,
              options: {},
              children: []
            },
            {
              name: :age,
              type: :integer,
              source: :user,
              required: false,
              options: { min: 0 },
              children: []
            }
          ]
        }
      end

      it "formats parameter with nested children using proper indentation" do
        result = described_class.call(parameter)

        expected = "Parameter: name=user type=hash source=context required=false options={} " \
                   "\n  ↳ Parameter: name=name type=string source=user required=true options={} " \
                   "\n  ↳ Parameter: name=age type=integer source=user required=false options={min: 0} "

        expect(result).to eq(expected)
      end
    end

    context "with deeply nested parameters" do
      let(:parameter) do
        {
          name: :root,
          type: :hash,
          source: :context,
          required: true,
          options: {},
          children: [
            {
              name: :level1,
              type: :hash,
              source: :user,
              required: true,
              options: {},
              children: [
                {
                  name: :level2,
                  type: :string,
                  source: :user,
                  required: false,
                  options: {},
                  children: []
                }
              ]
            }
          ]
        }
      end

      it "handles multiple nesting levels with correct indentation" do
        result = described_class.call(parameter)

        expected = "Parameter: name=root type=hash source=context required=true options={} " \
                   "\n  ↳ Parameter: name=level1 type=hash source=user required=true options={} " \
                   "\n    ↳ Parameter: name=level2 type=string source=user required=false options={} "

        expect(result).to eq(expected)
      end
    end

    context "with custom depth" do
      let(:parameter) do
        {
          name: :test,
          type: :string,
          source: :user,
          required: true,
          options: {},
          children: [
            {
              name: :child,
              type: :integer,
              source: :user,
              required: false,
              options: {},
              children: []
            }
          ]
        }
      end

      it "adjusts indentation based on provided depth" do
        result = described_class.call(parameter, 3)

        expected = "Parameter: name=test type=string source=user required=true options={} " \
                   "\n      ↳ Parameter: name=child type=integer source=user required=false options={} "

        expect(result).to eq(expected)
      end
    end

    context "with missing keys" do
      let(:parameter) do
        {
          name: :partial,
          type: :string,
          children: []
          # missing source, required, options
        }
      end

      it "handles missing keys gracefully" do
        result = described_class.call(parameter)

        expect(result).to eq("Parameter: name=partial type=string source= required= options= ")
      end
    end

    context "with empty children array" do
      let(:parameter) do
        {
          name: :empty_parent,
          type: :hash,
          source: :context,
          required: true,
          options: {},
          children: []
        }
      end

      it "formats parameter without children section" do
        result = described_class.call(parameter)

        expect(result).to eq("Parameter: name=empty_parent type=hash source=context required=true options={} ")
      end
    end

    context "with nil values" do
      let(:parameter) do
        {
          name: nil,
          type: :string,
          source: nil,
          required: false,
          options: nil,
          children: []
        }
      end

      it "handles nil values in parameter keys" do
        result = described_class.call(parameter)

        expect(result).to eq("Parameter: name= type=string source= required=false options= ")
      end
    end

    context "with complex options hash" do
      let(:parameter) do
        {
          name: :complex,
          type: :string,
          source: :user,
          required: true,
          options: { format: /\A\w+\z/, length: { min: 1, max: 50 }, transform: :downcase },
          children: []
        }
      end

      it "formats complex options hash correctly" do
        result = described_class.call(parameter)

        expect(result).to include("options={format: /\\A\\w+\\z/, length: {min: 1, max: 50}, transform: :downcase}")
      end
    end

    context "with symbol and string values" do
      let(:parameter) do
        {
          name: "string_name",
          type: "custom_type",
          source: :symbol_source,
          required: "false",
          options: { key: "value" },
          children: []
        }
      end

      it "preserves original value types in output" do
        result = described_class.call(parameter)

        expect(result).to eq('Parameter: name=string_name type=custom_type source=symbol_source required=false options={key: "value"} ')
      end
    end
  end

  describe "ORDERED_KEYS constant" do
    it "contains expected parameter keys in correct order" do
      expect(CMDx::ParameterInspector::ORDERED_KEYS).to eq(%i[name type source required options children])
    end

    it "is frozen to prevent modification" do
      expect(CMDx::ParameterInspector::ORDERED_KEYS).to be_frozen
    end
  end
end
