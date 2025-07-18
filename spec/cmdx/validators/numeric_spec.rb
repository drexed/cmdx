# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Numeric do
  subject(:validator) { described_class.new }

  describe ".call" do
    it "creates instance and calls #call method" do
      expect(described_class).to receive(:new).and_return(validator)
      expect(validator).to receive(:call).with(42, { min: 10 })

      described_class.call(42, { min: 10 })
    end
  end

  describe "#call" do
    context "with within validation" do
      it "allows values within the range" do
        expect { validator.call(5,  { within: 1..10 }) }.not_to raise_error
        expect { validator.call(1,  { within: 1..10 }) }.not_to raise_error
        expect { validator.call(10, { within: 1..10 }) }.not_to raise_error
      end

      it "allows values within the range using in alias" do
        expect { validator.call(5,  { in: 1..10 }) }.not_to raise_error
      end

      it "raises ValidationError when value is outside the range" do
        expect { validator.call(0,  { within: 1..10 }) }
          .to raise_error(CMDx::ValidationError, "must be within 1 and 10")
        expect { validator.call(11, { within: 1..10 }) }
          .to raise_error(CMDx::ValidationError, "must be within 1 and 10")
      end

      it "raises ValidationError when value is outside the range using in alias" do
        expect { validator.call(0, { in: 1..10 }) }
          .to raise_error(CMDx::ValidationError, "must be within 1 and 10")
      end

      it "works with exclusive ranges" do
        expect { validator.call(10, { within: 1...10 }) }
          .to raise_error(CMDx::ValidationError, "must be within 1 and 10")
        expect { validator.call(9, { within: 1...10 }) }.not_to raise_error
      end

      it "works with float ranges" do
        expect { validator.call(5.5,  { within: 1.0..10.0 }) }.not_to raise_error
        expect { validator.call(0.5,  { within: 1.0..10.0 }) }
          .to raise_error(CMDx::ValidationError, "must be within 1.0 and 10.0")
      end

      it "uses custom within_message when provided" do
        options = { within: 1..10, within_message: "Value must be between %{min} and %{max}" }

        expect { validator.call(0, options) }
          .to raise_error(CMDx::ValidationError, "Value must be between 1 and 10")
      end

      it "uses custom in_message when provided" do
        options = { in: 1..10, in_message: "Must be from %{min} to %{max}" }

        expect { validator.call(0, options) }
          .to raise_error(CMDx::ValidationError, "Must be from 1 to 10")
      end

      it "uses custom message when provided" do
        options = { within: 1..10, message: "Age must be between %{min} and %{max}" }

        expect { validator.call(0, options) }
          .to raise_error(CMDx::ValidationError, "Age must be between 1 and 10")
      end
    end

    context "with not_within validation" do
      it "allows values outside the range" do
        expect { validator.call(0,  { not_within: 1..10 }) }.not_to raise_error
        expect { validator.call(11, { not_within: 1..10 }) }.not_to raise_error
      end

      it "allows values outside the range using not_in alias" do
        expect { validator.call(0,  { not_in: 1..10 }) }.not_to raise_error
      end

      it "raises ValidationError when value is within the excluded range" do
        expect { validator.call(5,  { not_within: 1..10 }) }
          .to raise_error(CMDx::ValidationError, "must not be within 1 and 10")
        expect { validator.call(1,  { not_within: 1..10 }) }
          .to raise_error(CMDx::ValidationError, "must not be within 1 and 10")
      end

      it "raises ValidationError when value is within the excluded range using not_in alias" do
        expect { validator.call(5,  { not_in: 1..10 }) }
          .to raise_error(CMDx::ValidationError, "must not be within 1 and 10")
      end

      it "works with exclusive ranges" do
        expect { validator.call(10, { not_within: 1...10 }) }.not_to raise_error
        expect { validator.call(9, { not_within: 1...10 }) }
          .to raise_error(CMDx::ValidationError, "must not be within 1 and 10")
      end

      it "uses custom not_within_message when provided" do
        options = { not_within: 1..10, not_within_message: "Cannot be between %{min} and %{max}" }

        expect { validator.call(5, options) }
          .to raise_error(CMDx::ValidationError, "Cannot be between 1 and 10")
      end

      it "uses custom not_in_message when provided" do
        options = { not_in: 1..10, not_in_message: "Must not be from %{min} to %{max}" }

        expect { validator.call(5, options) }
          .to raise_error(CMDx::ValidationError, "Must not be from 1 to 10")
      end

      it "uses custom message when provided" do
        options = { not_within: 1..10, message: "Age cannot be between %{min} and %{max}" }

        expect { validator.call(5, options) }
          .to raise_error(CMDx::ValidationError, "Age cannot be between 1 and 10")
      end
    end

    context "with min/max validation" do
      it "allows values within min and max bounds" do
        expect { validator.call(15,  { min: 10, max: 20 }) }.not_to raise_error
        expect { validator.call(10,  { min: 10, max: 20 }) }.not_to raise_error
        expect { validator.call(20,  { min: 10, max: 20 }) }.not_to raise_error
      end

      it "raises ValidationError when value is outside min/max bounds" do
        expect { validator.call(9, { min: 10, max: 20 }) }
          .to raise_error(CMDx::ValidationError, "must be within 10 and 20")
        expect { validator.call(21, { min: 10, max: 20 }) }
          .to raise_error(CMDx::ValidationError, "must be within 10 and 20")
      end

      it "works with float values" do
        expect { validator.call(15.5,  { min: 10.0, max: 20.0 }) }.not_to raise_error
        expect { validator.call(9.9, { min: 10.0, max: 20.0 }) }
          .to raise_error(CMDx::ValidationError, "must be within 10.0 and 20.0")
      end
    end

    context "with min validation" do
      it "allows values at or above minimum" do
        expect { validator.call(10,  { min: 10 }) }.not_to raise_error
        expect { validator.call(15,  { min: 10 }) }.not_to raise_error
      end

      it "raises ValidationError when value is below minimum" do
        expect { validator.call(9, { min: 10 }) }
          .to raise_error(CMDx::ValidationError, "must be at least 10")
      end

      it "works with float values" do
        expect { validator.call(10.1, { min: 10.0 }) }.not_to raise_error
        expect { validator.call(9.9, { min: 10.0 }) }
          .to raise_error(CMDx::ValidationError, "must be at least 10.0")
      end

      it "uses custom min_message when provided" do
        options = { min: 18, min_message: "Must be at least %{min} years old" }

        expect { validator.call(17, options) }
          .to raise_error(CMDx::ValidationError, "Must be at least 18 years old")
      end

      it "uses custom message when provided" do
        options = { min: 18, message: "Age must be at least %{min}" }

        expect { validator.call(17, options) }
          .to raise_error(CMDx::ValidationError, "Age must be at least 18")
      end
    end

    context "with max validation" do
      it "allows values at or below maximum" do
        expect { validator.call(20,  { max: 20 }) }.not_to raise_error
        expect { validator.call(15,  { max: 20 }) }.not_to raise_error
      end

      it "raises ValidationError when value is above maximum" do
        expect { validator.call(21,  { max: 20 }) }
          .to raise_error(CMDx::ValidationError, "must be at most 20")
      end

      it "works with float values" do
        expect { validator.call(19.9,  { max: 20.0 }) }.not_to raise_error
        expect { validator.call(20.1,  { max: 20.0 }) }
          .to raise_error(CMDx::ValidationError, "must be at most 20.0")
      end

      it "uses custom max_message when provided" do
        options = { max: 65, max_message: "Cannot exceed %{max} years" }

        expect { validator.call(66, options) }
          .to raise_error(CMDx::ValidationError, "Cannot exceed 65 years")
      end

      it "uses custom message when provided" do
        options = { max: 65, message: "Age cannot exceed %{max}" }

        expect { validator.call(66, options) }
          .to raise_error(CMDx::ValidationError, "Age cannot exceed 65")
      end
    end

    context "with is validation" do
      it "allows values that match exactly" do
        expect { validator.call(42, { is: 42 }) }.not_to raise_error
        expect { validator.call(3.14,  { is: 3.14 }) }.not_to raise_error
      end

      it "raises ValidationError when value doesn't match exactly" do
        expect { validator.call(41,  { is: 42 }) }
          .to raise_error(CMDx::ValidationError, "must be 42")
        expect { validator.call(43,  { is: 42 }) }
          .to raise_error(CMDx::ValidationError, "must be 42")
      end

      it "works with negative values" do
        expect { validator.call(-10,  { is: -10 }) }.not_to raise_error
        expect { validator.call(-9, { is: -10 }) }
          .to raise_error(CMDx::ValidationError, "must be -10")
      end

      it "works with zero" do
        expect { validator.call(0,  { is: 0 }) }.not_to raise_error
        expect { validator.call(1,  { is: 0 }) }
          .to raise_error(CMDx::ValidationError, "must be 0")
      end

      it "uses custom is_message when provided" do
        options = { is: 100, is_message: "Value must be exactly %{is}" }

        expect { validator.call(99, options) }
          .to raise_error(CMDx::ValidationError, "Value must be exactly 100")
      end

      it "uses custom message when provided" do
        options = { is: 100, message: "Score must be %{is}" }

        expect { validator.call(99, options) }
          .to raise_error(CMDx::ValidationError, "Score must be 100")
      end
    end

    context "with is_not validation" do
      it "allows values that don't match" do
        expect { validator.call(41,  { is_not: 42 }) }.not_to raise_error
        expect { validator.call(43,  { is_not: 42 }) }.not_to raise_error
      end

      it "raises ValidationError when value matches exactly" do
        expect { validator.call(42,  { is_not: 42 }) }
          .to raise_error(CMDx::ValidationError, "must not be 42")
      end

      it "works with negative values" do
        expect { validator.call(-9,  { is_not: -10 }) }.not_to raise_error
        expect { validator.call(-10,  { is_not: -10 }) }
          .to raise_error(CMDx::ValidationError, "must not be -10")
      end

      it "works with zero" do
        expect { validator.call(1,  { is_not: 0 }) }.not_to raise_error
        expect { validator.call(0,  { is_not: 0 }) }
          .to raise_error(CMDx::ValidationError, "must not be 0")
      end

      it "uses custom is_not_message when provided" do
        options = { is_not: 13, is_not_message: "Value cannot be %{is_not}" }

        expect { validator.call(13, options) }
          .to raise_error(CMDx::ValidationError, "Value cannot be 13")
      end

      it "uses custom message when provided" do
        options = { is_not: 13, message: "Lucky number %{is_not} is not allowed" }

        expect { validator.call(13, options) }
          .to raise_error(CMDx::ValidationError, "Lucky number 13 is not allowed")
      end
    end

    context "with missing options" do
      it "raises ArgumentError when no numeric options are provided" do
        expect { validator.call(42, {}) }
          .to raise_error(ArgumentError, "no known numeric validator options given")
      end

      it "raises ArgumentError when numeric hash has unknown keys" do
        expect { validator.call(42, { unknown: "value" }) }
          .to raise_error(ArgumentError, "no known numeric validator options given")
      end
    end
  end

  describe "integration with tasks" do
    let(:task_class) do
      create_simple_task(name: "NumericValidationTask") do
        required :age, type: :integer, numeric: { min: 18, max: 65 }
        required :score, type: :float, numeric: { within: 0.0..100.0 }
        optional :quantity, type: :integer, default: 1, numeric: { min: 1 }

        def call
          context.validated_data = { age: age, score: score, quantity: quantity }
        end
      end
    end

    it "validates successfully with valid values" do
      result = task_class.call(age: 25, score: 85.5, quantity: 3)

      expect(result).to be_success
      expect(result.context.validated_data).to eq({ age: 25, score: 85.5, quantity: 3 })
    end

    it "fails when age is below minimum" do
      result = task_class.call(age: 17, score: 85.5)

      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("age must be within 18 and 65")
      expect(result.metadata[:messages]).to eq({ age: ["must be within 18 and 65"] })
    end

    it "fails when age is above maximum" do
      result = task_class.call(age: 66, score: 85.5)

      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("age must be within 18 and 65")
      expect(result.metadata[:messages]).to eq({ age: ["must be within 18 and 65"] })
    end

    it "fails when score is outside range" do
      result = task_class.call(age: 25, score: 105.0)

      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("score must be within 0.0 and 100.0")
      expect(result.metadata[:messages]).to eq({ score: ["must be within 0.0 and 100.0"] })
    end

    it "fails when quantity is below minimum" do
      result = task_class.call(age: 25, score: 85.5, quantity: 0)

      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("quantity must be at least 1")
      expect(result.metadata[:messages]).to eq({ quantity: ["must be at least 1"] })
    end

    it "validates with custom error messages" do
      custom_task = create_simple_task(name: "CustomMessageTask") do
        required :temperature, type: :float, numeric: {
          min: -40.0,
          max: 50.0,
          message: "Temperature must be between %{min}°C and %{max}°C"
        }

        def call
          context.temp = temperature
        end
      end

      result = custom_task.call(temperature: 60.0)

      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("temperature Temperature must be between -40.0°C and 50.0°C")
      expect(result.metadata[:messages]).to eq({ temperature: ["Temperature must be between -40.0°C and 50.0°C"] })
    end

    it "works with exact value validation" do
      exact_task = create_simple_task(name: "ExactValueTask") do
        required :magic_number, type: :integer, numeric: { is: 42 }

        def call
          context.magic = magic_number
        end
      end

      expect(exact_task.call(magic_number: 42)).to be_success

      result = exact_task.call(magic_number: 41)
      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("magic_number must be 42")
    end

    it "works with exclusion validation" do
      exclusion_task = create_simple_task(name: "ExclusionTask") do
        required :port, type: :integer, numeric: { is_not: 80, message: "Port %{is_not} is reserved" }

        def call
          context.port = port
        end
      end

      expect(exclusion_task.call(port: 8080)).to be_success

      result = exclusion_task.call(port: 80)
      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("port Port 80 is reserved")
    end

    it "works with multiple numeric validations" do
      multi_task = create_simple_task(name: "MultiValidationTask") do
        required :cpu_cores, type: :integer, numeric: { min: 1, max: 64 }
        required :memory_gb, type: :integer, numeric: { within: 1..256 }
        required :disk_gb, type: :integer, numeric: { min: 10 }

        def call
          context.config = { cpu_cores: cpu_cores, memory_gb: memory_gb, disk_gb: disk_gb }
        end
      end

      result = multi_task.call(cpu_cores: 4, memory_gb: 8, disk_gb: 100)
      expect(result).to be_success

      result = multi_task.call(cpu_cores: 0, memory_gb: 8, disk_gb: 100)
      expect(result).to be_failed

      result = multi_task.call(cpu_cores: 4, memory_gb: 300, disk_gb: 100)
      expect(result).to be_failed

      result = multi_task.call(cpu_cores: 4, memory_gb: 8, disk_gb: 5)
      expect(result).to be_failed
    end
  end
end
