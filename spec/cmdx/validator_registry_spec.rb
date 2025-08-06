# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ValidatorRegistry do
  subject(:registry) { described_class.new(initial_registry) }

  let(:initial_registry) { nil }
  let(:mock_validator) { instance_double("MockValidator") }
  let(:mock_task) { instance_double(CMDx::Task) }

  describe "#initialize" do
    context "when no registry is provided" do
      subject(:registry) { described_class.new }

      it "initializes with default coercions" do
        expect(registry.registry).to include(
          exclusion: CMDx::Validators::Exclusion,
          format: CMDx::Validators::Format,
          inclusion: CMDx::Validators::Inclusion,
          length: CMDx::Validators::Length,
          numeric: CMDx::Validators::Numeric,
          presence: CMDx::Validators::Presence
        )
      end
    end

    context "when a registry is provided" do
      let(:initial_registry) { { custom: mock_validator } }

      it "initializes with the provided registry" do
        expect(registry.registry).to eq({ custom: mock_validator })
      end
    end
  end

  describe "#registry" do
    let(:initial_registry) { { custom: mock_validator } }

    it "returns the internal registry hash" do
      expect(registry.registry).to eq({ custom: mock_validator })
    end
  end

  describe "#to_h" do
    let(:initial_registry) { { custom: mock_validator } }

    it "returns the registry hash" do
      expect(registry.to_h).to eq({ custom: mock_validator })
    end

    it "is an alias for registry" do
      expect(registry.method(:to_h)).to eq(registry.method(:registry))
    end
  end

  describe "#keys" do
    let(:initial_registry) { { custom: mock_validator, another: mock_validator } }

    it "returns the keys from the registry" do
      expect(registry.keys).to match_array(%i[custom another])
    end

    it "delegates to the registry hash" do
      allow(registry.registry).to receive(:keys).and_return([:delegated])

      expect(registry.keys).to eq([:delegated])
    end
  end

  describe "#dup" do
    it "returns a new ValidatorRegistry instance" do
      duplicated = registry.dup

      expect(duplicated).to be_a(described_class)
      expect(duplicated).not_to be(registry)
    end

    it "duplicates the registry hash" do
      duplicated = registry.dup

      expect(duplicated.registry).to eq(registry.registry)
      expect(duplicated.registry).not_to be(registry.registry)
    end

    it "allows independent modification of the duplicated registry" do
      duplicated = registry.dup

      duplicated.register(:new_type, mock_validator)

      expect(duplicated.registry).to have_key(:new_type)
      expect(registry.registry).not_to have_key(:new_type)
    end
  end

  describe "#register" do
    context "when registering a validator with string name" do
      it "adds the validator to the registry with symbol key" do
        registry.register("custom", mock_validator)

        expect(registry.registry[:custom]).to eq(mock_validator)
      end

      it "returns self for method chaining" do
        result = registry.register("custom", mock_validator)

        expect(result).to be(registry)
      end
    end

    context "when registering a validator with symbol name" do
      it "adds the validator to the registry" do
        registry.register(:custom, mock_validator)

        expect(registry.registry[:custom]).to eq(mock_validator)
      end
    end

    context "when registering to an existing registry" do
      let(:initial_registry) { { existing: "existing_validator" } }

      it "adds new validator to existing ones" do
        registry.register(:new_type, mock_validator)

        expect(registry.registry).to include(existing: "existing_validator", new_type: mock_validator)
      end
    end

    context "when registering over an existing validator" do
      let(:initial_registry) { { existing: "old_validator" } }

      it "overwrites the existing validator" do
        registry.register(:existing, mock_validator)

        expect(registry.registry[:existing]).to eq(mock_validator)
      end
    end
  end

  describe "#validate" do
    let(:initial_registry) { { custom: mock_validator } }
    let(:value) { "test_value" }
    let(:options) { { option1: "value1" } }

    before do
      allow(CMDx::Utils::Call).to receive(:invoke).and_return("validation_result")
      allow(CMDx::Utils::Condition).to receive(:evaluate).and_return(true)
    end

    context "when validator type exists" do
      context "with hash options" do
        it "evaluates condition and calls Utils::Call.invoke when condition is true" do
          registry.validate(:custom, mock_task, value, options)

          expect(CMDx::Utils::Condition).to have_received(:evaluate).with(mock_task, options, value)
          expect(CMDx::Utils::Call).to have_received(:invoke).with(
            mock_task, mock_validator, value, options
          )
        end

        it "returns the result from Utils::Call.invoke" do
          result = registry.validate(:custom, mock_task, value, options)

          expect(result).to eq("validation_result")
        end

        context "when condition evaluates to false" do
          before do
            allow(CMDx::Utils::Condition).to receive(:evaluate).and_return(false)
          end

          it "does not call the validator" do
            registry.validate(:custom, mock_task, value, options)

            expect(CMDx::Utils::Call).not_to have_received(:invoke)
          end

          it "returns nil" do
            result = registry.validate(:custom, mock_task, value, options)

            expect(result).to be_nil
          end
        end

        context "with allow_nil option and nil value" do
          let(:value) { nil }
          let(:options) { { allow_nil: true } }

          it "calls the validator" do
            registry.validate(:custom, mock_task, value, options)

            expect(CMDx::Utils::Call).to have_received(:invoke).with(
              mock_task, mock_validator, value, options
            )
          end

          it "returns the result from Utils::Call.invoke" do
            result = registry.validate(:custom, mock_task, value, options)

            expect(result).to eq("validation_result")
          end
        end

        context "with allow_nil option and non-nil value" do
          let(:options) { { allow_nil: true } }

          it "does not call the validator" do
            registry.validate(:custom, mock_task, value, options)

            expect(CMDx::Utils::Call).not_to have_received(:invoke)
          end

          it "returns nil" do
            result = registry.validate(:custom, mock_task, value, options)

            expect(result).to be_nil
          end
        end

        context "with allow_nil false and nil value" do
          let(:value) { nil }
          let(:options) { { allow_nil: false } }

          it "does not call the validator" do
            registry.validate(:custom, mock_task, value, options)

            expect(CMDx::Utils::Call).not_to have_received(:invoke)
          end

          it "returns nil" do
            result = registry.validate(:custom, mock_task, value, options)

            expect(result).to be_nil
          end
        end
      end

      context "with non-hash options" do
        let(:options) { true }

        it "uses options directly as condition" do
          registry.validate(:custom, mock_task, value, options)

          expect(CMDx::Utils::Condition).not_to have_received(:evaluate)
          expect(CMDx::Utils::Call).to have_received(:invoke).with(
            mock_task, mock_validator, value, options
          )
        end

        context "when options is false" do
          let(:options) { false }

          it "does not call the validator" do
            registry.validate(:custom, mock_task, value, options)

            expect(CMDx::Utils::Call).not_to have_received(:invoke)
          end

          it "returns nil" do
            result = registry.validate(:custom, mock_task, value, options)

            expect(result).to be_nil
          end
        end
      end

      context "with string type name" do
        let(:initial_registry) { { "custom" => mock_validator } }

        it "works with string type names" do
          registry.validate("custom", mock_task, value, options)

          expect(CMDx::Utils::Call).to have_received(:invoke).with(
            mock_task, mock_validator, value, options
          )
        end
      end
    end

    context "when options are not provided" do
      it "passes empty hash as options and evaluates condition" do
        registry.validate(:custom, mock_task, value)

        expect(CMDx::Utils::Condition).to have_received(:evaluate).with(mock_task, {}, value)
        expect(CMDx::Utils::Call).to have_received(:invoke).with(
          mock_task, mock_validator, value, {}
        )
      end
    end

    context "when validator type does not exist" do
      it "raises TypeError with descriptive message" do
        expect { registry.validate(:nonexistent, mock_task, value) }
          .to raise_error(TypeError, "unknown validator type :nonexistent")
      end

      it "raises TypeError for string type names" do
        expect { registry.validate("string", mock_task, value) }
          .to raise_error(TypeError, 'unknown validator type "string"')
      end
    end

    context "when type is nil" do
      it "raises TypeError" do
        expect { registry.validate(nil, mock_task, value) }
          .to raise_error(TypeError, "unknown validator type nil")
      end
    end
  end
end
