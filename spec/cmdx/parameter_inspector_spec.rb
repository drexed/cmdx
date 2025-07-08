# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ParameterInspector do
  describe ".call" do
    context "when inspecting basic parameter information" do
      it "formats parameter with all basic attributes" do
        parameter = {
          name: :user_id,
          type: :integer,
          source: :context,
          required: true,
          options: {},
          children: []
        }

        result = described_class.call(parameter)

        expect(result).to eq("Parameter: name=user_id type=integer source=context required=true options={} ")
      end

      it "formats parameter with minimal attributes" do
        parameter = {
          name: :title,
          type: :string,
          source: :context,
          required: false,
          options: {},
          children: []
        }

        result = described_class.call(parameter)

        expect(result).to eq("Parameter: name=title type=string source=context required=false options={} ")
      end

      it "handles nil values by filtering them out" do
        parameter = {
          name: :value,
          type: nil,
          source: :context,
          required: true,
          options: {},
          children: []
        }

        result = described_class.call(parameter)

        expect(result).to eq("Parameter: name=value type= source=context required=true options={} ")
      end
    end

    context "when inspecting parameter names" do
      it "displays symbol names correctly" do
        parameter = {
          name: :email_address,
          type: :string,
          source: :context,
          required: true,
          options: {},
          children: []
        }

        result = described_class.call(parameter)

        expect(result).to include("name=email_address")
      end

      it "displays string names correctly" do
        parameter = {
          name: "user_name",
          type: :string,
          source: :context,
          required: true,
          options: {},
          children: []
        }

        result = described_class.call(parameter)

        expect(result).to include("name=user_name")
      end
    end

    context "when inspecting different parameter types" do
      it "displays string type" do
        parameter = {
          name: :title,
          type: :string,
          source: :context,
          required: true,
          options: {},
          children: []
        }

        result = described_class.call(parameter)

        expect(result).to include("type=string")
      end

      it "displays integer type" do
        parameter = {
          name: :count,
          type: :integer,
          source: :context,
          required: true,
          options: {},
          children: []
        }

        result = described_class.call(parameter)

        expect(result).to include("type=integer")
      end

      it "displays virtual type" do
        parameter = {
          name: :metadata,
          type: :virtual,
          source: :context,
          required: false,
          options: {},
          children: []
        }

        result = described_class.call(parameter)

        expect(result).to include("type=virtual")
      end

      it "displays array type" do
        parameter = {
          name: :tags,
          type: :array,
          source: :context,
          required: false,
          options: {},
          children: []
        }

        result = described_class.call(parameter)

        expect(result).to include("type=array")
      end

      it "displays multiple types as array" do
        parameter = {
          name: :value,
          type: %i[string integer],
          source: :context,
          required: false,
          options: {},
          children: []
        }

        result = described_class.call(parameter)

        expect(result).to include("type=[:string, :integer]")
      end
    end

    context "when inspecting different parameter sources" do
      it "displays context source" do
        parameter = {
          name: :user_id,
          type: :integer,
          source: :context,
          required: true,
          options: {},
          children: []
        }

        result = described_class.call(parameter)

        expect(result).to include("source=context")
      end

      it "displays custom source" do
        parameter = {
          name: :profile,
          type: :hash,
          source: :user,
          required: false,
          options: {},
          children: []
        }

        result = described_class.call(parameter)

        expect(result).to include("source=user")
      end

      it "displays proc source" do
        source_proc = -> { current_user }
        parameter = {
          name: :data,
          type: :virtual,
          source: source_proc,
          required: false,
          options: {},
          children: []
        }

        result = described_class.call(parameter)

        expect(result).to include("source=#{source_proc}")
      end
    end

    context "when inspecting required status" do
      it "displays true for required parameters" do
        parameter = {
          name: :user_id,
          type: :integer,
          source: :context,
          required: true,
          options: {},
          children: []
        }

        result = described_class.call(parameter)

        expect(result).to include("required=true")
      end

      it "displays false for optional parameters" do
        parameter = {
          name: :priority,
          type: :string,
          source: :context,
          required: false,
          options: {},
          children: []
        }

        result = described_class.call(parameter)

        expect(result).to include("required=false")
      end
    end

    context "when inspecting parameter options" do
      it "displays empty options hash" do
        parameter = {
          name: :simple,
          type: :string,
          source: :context,
          required: true,
          options: {},
          children: []
        }

        result = described_class.call(parameter)

        expect(result).to include("options={}")
      end

      it "displays validation options" do
        parameter = {
          name: :email,
          type: :string,
          source: :context,
          required: true,
          options: { format: { with: /@/ }, presence: true },
          children: []
        }

        result = described_class.call(parameter)

        expect(result).to include("options={format: {with: /@/}, presence: true}")
      end

      it "displays numeric validation options" do
        parameter = {
          name: :age,
          type: :integer,
          source: :context,
          required: true,
          options: { numeric: { min: 18, max: 120 } },
          children: []
        }

        result = described_class.call(parameter)

        expect(result).to include("options={numeric: {min: 18, max: 120}}")
      end

      it "displays complex nested options" do
        parameter = {
          name: :config,
          type: :hash,
          source: :context,
          required: false,
          options: {
            presence: true,
            as: :configuration
          },
          children: []
        }

        result = described_class.call(parameter)

        expect(result).to include("options={presence: true, as: :configuration}")
      end
    end

    context "when inspecting nested parameters" do
      it "formats single-level nested parameters with proper indentation" do
        parameter = {
          name: :address,
          type: :virtual,
          source: :context,
          required: true,
          options: {},
          children: [
            {
              name: :street,
              type: :string,
              source: :address,
              required: true,
              options: {},
              children: []
            }
          ]
        }

        result = described_class.call(parameter)

        expected = "Parameter: name=address type=virtual source=context required=true options={} \n  ↳ Parameter: name=street type=string source=address required=true options={} "
        expect(result).to eq(expected)
      end

      it "formats multiple child parameters" do
        parameter = {
          name: :user,
          type: :virtual,
          source: :context,
          required: true,
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
              name: :email,
              type: :string,
              source: :user,
              required: true,
              options: {},
              children: []
            }
          ]
        }

        result = described_class.call(parameter)

        expected = "Parameter: name=user type=virtual source=context required=true options={} \n  ↳ Parameter: name=name type=string source=user required=true options={} \n  ↳ Parameter: name=email type=string source=user required=true options={} "
        expect(result).to eq(expected)
      end

      it "formats deeply nested parameters with increasing indentation" do
        parameter = {
          name: :order,
          type: :virtual,
          source: :context,
          required: true,
          options: {},
          children: [
            {
              name: :billing,
              type: :virtual,
              source: :order,
              required: true,
              options: {},
              children: [
                {
                  name: :address,
                  type: :string,
                  source: :billing,
                  required: true,
                  options: {},
                  children: []
                }
              ]
            }
          ]
        }

        result = described_class.call(parameter)

        expected = "Parameter: name=order type=virtual source=context required=true options={} \n  ↳ Parameter: name=billing type=virtual source=order required=true options={} \n    ↳ Parameter: name=address type=string source=billing required=true options={} "
        expect(result).to eq(expected)
      end

      it "handles empty children arrays" do
        parameter = {
          name: :simple,
          type: :string,
          source: :context,
          required: true,
          options: {},
          children: []
        }

        result = described_class.call(parameter)

        expect(result).to eq("Parameter: name=simple type=string source=context required=true options={} ")
      end
    end

    context "when using custom depth parameter" do
      it "applies custom starting depth for indentation" do
        parameter = {
          name: :nested,
          type: :virtual,
          source: :context,
          required: true,
          options: {},
          children: [
            {
              name: :child,
              type: :string,
              source: :nested,
              required: true,
              options: {},
              children: []
            }
          ]
        }

        result = described_class.call(parameter, 2)

        expected = "Parameter: name=nested type=virtual source=context required=true options={} \n    ↳ Parameter: name=child type=string source=nested required=true options={} "
        expect(result).to eq(expected)
      end

      it "increases indentation proportionally with depth" do
        parameter = {
          name: :root,
          type: :virtual,
          source: :context,
          required: true,
          options: {},
          children: [
            {
              name: :level1,
              type: :virtual,
              source: :root,
              required: true,
              options: {},
              children: [
                {
                  name: :level2,
                  type: :string,
                  source: :level1,
                  required: true,
                  options: {},
                  children: []
                }
              ]
            }
          ]
        }

        result = described_class.call(parameter, 3)

        expected = "Parameter: name=root type=virtual source=context required=true options={} \n      ↳ Parameter: name=level1 type=virtual source=root required=true options={} \n        ↳ Parameter: name=level2 type=string source=level1 required=true options={} "
        expect(result).to eq(expected)
      end
    end

    context "when inspecting parameters with missing attributes" do
      it "handles parameters with missing optional attributes" do
        parameter = {
          name: :basic,
          type: :string,
          required: true,
          children: []
        }

        result = described_class.call(parameter)

        expect(result).to eq("Parameter: name=basic type=string source= required=true options= ")
      end

      it "handles parameters with only name" do
        parameter = {
          name: :minimal,
          children: []
        }

        result = described_class.call(parameter)

        expect(result).to eq("Parameter: name=minimal type= source= required= options= ")
      end

      it "handles empty parameter hash" do
        parameter = { children: [] }

        result = described_class.call(parameter)

        expect(result).to eq("Parameter: name= type= source= required= options= ")
      end
    end

    context "when inspecting parameters with special values" do
      it "handles boolean false values correctly" do
        parameter = {
          name: :disabled,
          type: :boolean,
          source: :context,
          required: false,
          options: { default: false },
          children: []
        }

        result = described_class.call(parameter)

        expect(result).to include("required=false")
        expect(result).to include("options={default: false}")
      end

      it "handles zero and empty string values" do
        parameter = {
          name: :count,
          type: :integer,
          source: :context,
          required: 0,
          options: { default: "" },
          children: []
        }

        result = described_class.call(parameter)

        expect(result).to include("required=0")
        expect(result).to include("options={default: \"\"}")
      end

      it "handles complex object values" do
        regex = /\A\w+\z/
        parameter = {
          name: :pattern,
          type: :string,
          source: :context,
          required: true,
          options: { format: { with: regex } },
          children: []
        }

        result = described_class.call(parameter)

        expect(result).to include("options={format: {with: /\\A\\w+\\z/}}")
      end
    end

    context "when inspecting attribute ordering" do
      it "maintains consistent attribute order regardless of input order" do
        parameter = {
          children: [],
          options: { presence: true },
          required: true,
          source: :context,
          type: :string,
          name: :reordered
        }

        result = described_class.call(parameter)

        expect(result).to eq("Parameter: name=reordered type=string source=context required=true options={presence: true} ")
      end

      it "places name first in output" do
        parameter = {
          type: :integer,
          name: :user_id,
          source: :context,
          required: true,
          options: {},
          children: []
        }

        result = described_class.call(parameter)

        expect(result).to start_with("Parameter: name=user_id")
      end

      it "formats nested parameters with newlines and indentation" do
        parameter = {
          name: :parent,
          type: :virtual,
          source: :context,
          required: true,
          options: {},
          children: [
            {
              name: :child,
              type: :string,
              source: :parent,
              required: true,
              options: {},
              children: []
            }
          ]
        }

        result = described_class.call(parameter)

        lines = result.split("\n")
        expect(lines.size).to eq(2)
        expect(lines[0]).to start_with("Parameter: name=parent")
        expect(lines[1]).to start_with("  ↳ Parameter: name=child")
      end
    end

    context "when testing edge cases" do
      it "handles very deeply nested structures" do
        parameter = {
          name: :deep,
          type: :virtual,
          source: :context,
          required: true,
          options: {},
          children: [
            {
              name: :level1,
              type: :virtual,
              source: :deep,
              required: true,
              options: {},
              children: [
                {
                  name: :level2,
                  type: :virtual,
                  source: :level1,
                  required: true,
                  options: {},
                  children: [
                    {
                      name: :level3,
                      type: :string,
                      source: :level2,
                      required: true,
                      options: {},
                      children: []
                    }
                  ]
                }
              ]
            }
          ]
        }

        result = described_class.call(parameter)

        lines = result.split("\n")
        expect(lines.size).to eq(4)
        expect(lines[0]).to start_with("Parameter: name=deep")
        expect(lines[1]).to start_with("  ↳ Parameter: name=level1")
        expect(lines[2]).to start_with("    ↳ Parameter: name=level2")
        expect(lines[3]).to start_with("      ↳ Parameter: name=level3")
      end

      it "handles mixed data types in nested structures" do
        parameter = {
          name: :mixed,
          type: :virtual,
          source: :context,
          required: true,
          options: { custom: true },
          children: [
            {
              name: 123,
              type: %i[string integer],
              source: :mixed,
              required: false,
              options: { default: nil },
              children: []
            }
          ]
        }

        result = described_class.call(parameter)

        expect(result).to include("name=mixed")
        expect(result).to include("name=123")
        expect(result).to include("type=[:string, :integer]")
        expect(result).to include("required=false")
        expect(result).to include("options={default: nil}")
      end
    end
  end
end
