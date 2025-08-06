# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::CoercionRegistry do
  subject(:registry) { described_class.new(initial_registry) }

  let(:initial_registry) { nil }
  let(:mock_coercion) { instance_double("MockCoercion") }
  let(:mock_task) { instance_double(CMDx::Task) }

  describe "#initialize" do
    context "when no registry is provided" do
      subject(:registry) { described_class.new }

      it "initializes with default coercions" do
        expect(registry.registry).to include(
          array: CMDx::Coercions::Array,
          big_decimal: CMDx::Coercions::BigDecimal,
          boolean: CMDx::Coercions::Boolean,
          complex: CMDx::Coercions::Complex,
          date: CMDx::Coercions::Date,
          datetime: CMDx::Coercions::DateTime,
          float: CMDx::Coercions::Float,
          hash: CMDx::Coercions::Hash,
          integer: CMDx::Coercions::Integer,
          rational: CMDx::Coercions::Rational,
          string: CMDx::Coercions::String,
          time: CMDx::Coercions::Time
        )
      end
    end

    context "when a registry is provided" do
      let(:initial_registry) { { custom: mock_coercion } }

      it "initializes with the provided registry" do
        expect(registry.registry).to eq({ custom: mock_coercion })
      end
    end
  end

  describe "#registry" do
    let(:initial_registry) { { custom: mock_coercion } }

    it "returns the internal registry hash" do
      expect(registry.registry).to eq({ custom: mock_coercion })
    end
  end

  describe "#to_h" do
    let(:initial_registry) { { custom: mock_coercion } }

    it "returns the registry hash" do
      expect(registry.to_h).to eq({ custom: mock_coercion })
    end

    it "is an alias for registry" do
      expect(registry.method(:to_h)).to eq(registry.method(:registry))
    end
  end

  describe "#dup" do
    it "returns a new CoercionRegistry instance" do
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

      duplicated.register(:new_type, mock_coercion)

      expect(duplicated.registry).to have_key(:new_type)
      expect(registry.registry).not_to have_key(:new_type)
    end
  end

  describe "#register" do
    context "when registering a coercion with string name" do
      it "adds the coercion to the registry with symbol key" do
        registry.register("custom", mock_coercion)

        expect(registry.registry[:custom]).to eq(mock_coercion)
      end

      it "returns self for method chaining" do
        result = registry.register("custom", mock_coercion)

        expect(result).to be(registry)
      end
    end

    context "when registering a coercion with symbol name" do
      it "adds the coercion to the registry" do
        registry.register(:custom, mock_coercion)

        expect(registry.registry[:custom]).to eq(mock_coercion)
      end
    end

    context "when registering to an existing registry" do
      let(:initial_registry) { { existing: "existing_coercion" } }

      it "adds new coercion to existing ones" do
        registry.register(:new_type, mock_coercion)

        expect(registry.registry).to include(existing: "existing_coercion", new_type: mock_coercion)
      end
    end

    context "when registering over an existing coercion" do
      let(:initial_registry) { { existing: "old_coercion" } }

      it "overwrites the existing coercion" do
        registry.register(:existing, mock_coercion)

        expect(registry.registry[:existing]).to eq(mock_coercion)
      end
    end
  end

  describe "#coerce" do
    let(:initial_registry) { { custom: mock_coercion } }
    let(:value) { "test_value" }
    let(:options) { { option1: "value1" } }

    before do
      allow(CMDx::Utils::Call).to receive(:invoke).and_return("coerced_value")
    end

    context "when coercion type exists" do
      it "calls Utils::Call.invoke with correct parameters" do
        registry.coerce(:custom, mock_task, value, options)

        expect(CMDx::Utils::Call).to have_received(:invoke).with(
          mock_task, mock_coercion, value, options
        )
      end

      it "returns the result from Utils::Call.invoke" do
        result = registry.coerce(:custom, mock_task, value, options)

        expect(result).to eq("coerced_value")
      end

      context "with string type name" do
        let(:initial_registry) { { "custom" => mock_coercion } }

        it "works with string type names" do
          registry.coerce("custom", mock_task, value, options)

          expect(CMDx::Utils::Call).to have_received(:invoke).with(
            mock_task, mock_coercion, value, options
          )
        end
      end
    end

    context "when options are not provided" do
      it "passes empty hash as options" do
        registry.coerce(:custom, mock_task, value)

        expect(CMDx::Utils::Call).to have_received(:invoke).with(
          mock_task, mock_coercion, value, {}
        )
      end
    end

    context "when coercion type does not exist" do
      it "raises TypeError with descriptive message" do
        expect { registry.coerce(:nonexistent, mock_task, value) }
          .to raise_error(TypeError, "unknown coercion type :nonexistent")
      end

      it "raises TypeError for string type names" do
        expect { registry.coerce("string", mock_task, value) }
          .to raise_error(TypeError, 'unknown coercion type "string"')
      end
    end

    context "when type is nil" do
      it "raises TypeError" do
        expect { registry.coerce(nil, mock_task, value) }
          .to raise_error(TypeError, "unknown coercion type nil")
      end
    end
  end
end
