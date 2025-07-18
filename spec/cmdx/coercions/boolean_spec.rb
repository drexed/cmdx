# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Boolean do
  subject(:coercion) { described_class.new }

  describe ".call" do
    it "creates instance and calls #call method" do
      expect(described_class.call("true")).to be true
    end
  end

  describe "#call" do
    context "with truthy string values" do
      it "converts 'true' to true" do
        result = coercion.call("true")

        expect(result).to be true
      end

      it "converts 'TRUE' to true (case insensitive)" do
        result = coercion.call("TRUE")

        expect(result).to be true
      end

      it "converts 't' to true" do
        result = coercion.call("t")

        expect(result).to be true
      end

      it "converts 'T' to true (case insensitive)" do
        result = coercion.call("T")

        expect(result).to be true
      end

      it "converts 'yes' to true" do
        result = coercion.call("yes")

        expect(result).to be true
      end

      it "converts 'YES' to true (case insensitive)" do
        result = coercion.call("YES")

        expect(result).to be true
      end

      it "converts 'y' to true" do
        result = coercion.call("y")

        expect(result).to be true
      end

      it "converts 'Y' to true (case insensitive)" do
        result = coercion.call("Y")

        expect(result).to be true
      end

      it "converts '1' to true" do
        result = coercion.call("1")

        expect(result).to be true
      end
    end

    context "with falsey string values" do
      it "converts 'false' to false" do
        result = coercion.call("false")

        expect(result).to be false
      end

      it "converts 'FALSE' to false (case insensitive)" do
        result = coercion.call("FALSE")

        expect(result).to be false
      end

      it "converts 'f' to false" do
        result = coercion.call("f")

        expect(result).to be false
      end

      it "converts 'F' to false (case insensitive)" do
        result = coercion.call("F")

        expect(result).to be false
      end

      it "converts 'no' to false" do
        result = coercion.call("no")

        expect(result).to be false
      end

      it "converts 'NO' to false (case insensitive)" do
        result = coercion.call("NO")

        expect(result).to be false
      end

      it "converts 'n' to false" do
        result = coercion.call("n")

        expect(result).to be false
      end

      it "converts 'N' to false (case insensitive)" do
        result = coercion.call("N")

        expect(result).to be false
      end

      it "converts '0' to false" do
        result = coercion.call("0")

        expect(result).to be false
      end
    end

    context "with boolean values" do
      it "converts true to true" do
        result = coercion.call(true)

        expect(result).to be true
      end

      it "converts false to false" do
        result = coercion.call(false)

        expect(result).to be false
      end
    end

    context "with numeric values" do
      it "converts 1 to true" do
        result = coercion.call(1)

        expect(result).to be true
      end

      it "converts 0 to false" do
        result = coercion.call(0)

        expect(result).to be false
      end

      it "raises CoercionError for other numbers" do
        expect { coercion.call(2) }.to raise_error(CMDx::CoercionError, /could not coerce into a boolean/)
      end

      it "raises CoercionError for floats" do
        expect { coercion.call(1.5) }.to raise_error(CMDx::CoercionError, /could not coerce into a boolean/)
      end
    end

    context "with invalid values" do
      it "raises CoercionError for invalid strings" do
        expect { coercion.call("invalid") }.to raise_error(CMDx::CoercionError, /could not coerce into a boolean/)
      end

      it "raises CoercionError for empty strings" do
        expect { coercion.call("") }.to raise_error(CMDx::CoercionError, /could not coerce into a boolean/)
      end

      it "raises CoercionError for whitespace strings" do
        expect { coercion.call("   ") }.to raise_error(CMDx::CoercionError, /could not coerce into a boolean/)
      end

      it "raises CoercionError for partial matches" do
        expect { coercion.call("tr") }.to raise_error(CMDx::CoercionError, /could not coerce into a boolean/)
      end

      it "raises CoercionError for strings with extra characters" do
        expect { coercion.call("true!") }.to raise_error(CMDx::CoercionError, /could not coerce into a boolean/)
      end

      it "raises CoercionError for nil" do
        expect { coercion.call(nil) }.to raise_error(CMDx::CoercionError, /could not coerce into a boolean/)
      end

      it "raises CoercionError for arrays" do
        expect { coercion.call([true, false]) }.to raise_error(CMDx::CoercionError, /could not coerce into a boolean/)
      end

      it "raises CoercionError for hashes" do
        expect { coercion.call({ value: true }) }.to raise_error(CMDx::CoercionError, /could not coerce into a boolean/)
      end

      it "raises CoercionError for objects" do
        expect { coercion.call(Object.new) }.to raise_error(CMDx::CoercionError, /could not coerce into a boolean/)
      end
    end

    context "with options parameter" do
      it "ignores options parameter for valid values" do
        result = coercion.call("true", { some: "option" })

        expect(result).to be true
      end

      it "ignores options parameter for invalid values" do
        expect { coercion.call("invalid", { some: "option" }) }.to raise_error(CMDx::CoercionError, /could not coerce into a boolean/)
      end
    end
  end

  describe "integration with tasks" do
    let(:task_class) do
      create_simple_task(name: "ToggleFeatureTask") do
        required :enabled, type: :boolean
        optional :force, type: :boolean, default: false

        def call
          context.feature_enabled = enabled
          context.force_applied = force
        end
      end
    end

    it "coerces string 'true' to boolean true" do
      result = task_class.call(enabled: "true")

      expect(result).to be_success
      expect(result.context.feature_enabled).to be true
    end

    it "coerces string 'false' to boolean false" do
      result = task_class.call(enabled: "false")

      expect(result).to be_success
      expect(result.context.feature_enabled).to be false
    end

    it "coerces 'yes' to boolean true" do
      result = task_class.call(enabled: "yes")

      expect(result).to be_success
      expect(result.context.feature_enabled).to be true
    end

    it "coerces 'no' to boolean false" do
      result = task_class.call(enabled: "no")

      expect(result).to be_success
      expect(result.context.feature_enabled).to be false
    end

    it "coerces '1' to boolean true" do
      result = task_class.call(enabled: "1")

      expect(result).to be_success
      expect(result.context.feature_enabled).to be true
    end

    it "coerces '0' to boolean false" do
      result = task_class.call(enabled: "0")

      expect(result).to be_success
      expect(result.context.feature_enabled).to be false
    end

    it "handles boolean parameters unchanged" do
      result = task_class.call(enabled: true)

      expect(result).to be_success
      expect(result.context.feature_enabled).to be true
    end

    it "uses default values for optional boolean parameters" do
      result = task_class.call(enabled: true)

      expect(result).to be_success
      expect(result.context.force_applied).to be false
    end

    it "coerces optional parameters when provided" do
      result = task_class.call(enabled: true, force: "yes")

      expect(result).to be_success
      expect(result.context.force_applied).to be true
    end

    it "fails when coercion fails for invalid values" do
      result = task_class.call(enabled: "invalid")

      expect(result).to be_failed
      expect(result.metadata[:reason]).to include("could not coerce into a boolean")
    end

    it "handles case-insensitive coercion" do
      result = task_class.call(enabled: "TRUE", force: "FALSE")

      expect(result).to be_success
      expect(result.context.feature_enabled).to be true
      expect(result.context.force_applied).to be false
    end
  end
end
