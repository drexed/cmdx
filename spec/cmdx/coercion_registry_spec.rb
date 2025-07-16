# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::CoercionRegistry do
  subject(:registry) { described_class.new }

  let(:task) { create_simple_task(name: "TestTask").new }

  describe "#initialize" do
    it "creates registry with default coercions" do
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
        time: CMDx::Coercions::Time,
        virtual: CMDx::Coercions::Virtual
      )
    end

    it "includes all expected coercion types" do
      expect(registry.registry.keys).to contain_exactly(
        :array, :big_decimal, :boolean, :complex, :date, :datetime,
        :float, :hash, :integer, :rational, :string, :time, :virtual
      )
    end
  end

  describe "#register" do
    let(:custom_coercion) do
      Class.new do
        def self.call(value, _options = {})
          value.to_s.upcase
        end
      end
    end

    it "registers custom coercion class" do
      registry.register(:upcase, custom_coercion)

      expect(registry.registry[:upcase]).to eq(custom_coercion)
    end

    it "registers proc coercion" do
      proc_coercion = ->(value, _options) { value.to_s.reverse }
      registry.register(:reverse, proc_coercion)

      expect(registry.registry[:reverse]).to eq(proc_coercion)
    end

    it "registers symbol coercion" do
      registry.register(:symbol_coercion, :upcase)

      expect(registry.registry[:symbol_coercion]).to eq(:upcase)
    end

    it "registers string coercion" do
      registry.register(:string_coercion, "to_s")

      expect(registry.registry[:string_coercion]).to eq("to_s")
    end

    it "returns self for method chaining" do
      result = registry.register(:custom1, custom_coercion)

      expect(result).to eq(registry)
    end

    it "supports method chaining with multiple registrations" do
      result =
        registry
        .register(:custom1, custom_coercion)
        .register(:custom2, ->(value, _options) { value.to_i })

      expect(result).to eq(registry)
      expect(registry.registry[:custom1]).to eq(custom_coercion)
      expect(registry.registry[:custom2]).to be_a(Proc)
    end

    it "overwrites existing registrations" do
      registry.register(:string, custom_coercion)

      expect(registry.registry[:string]).to eq(custom_coercion)
    end
  end

  describe "#call" do
    context "with built-in coercions" do
      it "executes string coercion" do
        result = registry.call(task, :string, 123)

        expect(result).to eq("123")
      end

      it "executes integer coercion" do
        result = registry.call(task, :integer, "42")

        expect(result).to eq(42)
      end

      it "executes boolean coercion" do
        result = registry.call(task, :boolean, "true")

        expect(result).to be true
      end

      it "executes virtual coercion" do
        value = { test: "data" }
        result = registry.call(task, :virtual, value)

        expect(result).to eq(value)
      end

      it "passes options to coercions" do
        result = registry.call(task, :big_decimal, "123.456", precision: 10)

        expect(result).to be_a(BigDecimal)
        expect(result.to_f).to eq(123.456)
      end
    end

    context "with custom coercion classes" do
      let(:custom_coercion) do
        Class.new do
          def self.call(value, options = {})
            prefix = options[:prefix] || ""
            "#{prefix}#{value.to_s.upcase}"
          end
        end
      end

      before do
        registry.register(:custom, custom_coercion)
      end

      it "executes custom coercion class" do
        result = registry.call(task, :custom, "hello")

        expect(result).to eq("HELLO")
      end

      it "passes options to custom coercion" do
        result = registry.call(task, :custom, "hello", prefix: "PREFIX_")

        expect(result).to eq("PREFIX_HELLO")
      end
    end

    context "with symbol/string/proc coercions" do
      let(:test_task) do
        create_task_class(name: "TestCoercionTask") do
          def upcase_method(value, _options = {})
            value.to_s.upcase
          end

          def call
            context.executed = true
          end
        end.new
      end

      it "executes symbol coercion via cmdx_try" do
        registry.register(:symbol_test, :upcase_method)

        result = registry.call(test_task, :symbol_test, "hello")

        expect(result).to eq("HELLO")
      end

      it "executes string coercion via cmdx_try" do
        registry.register(:string_test, "upcase_method")

        result = registry.call(test_task, :string_test, "world")

        expect(result).to eq("WORLD")
      end

      it "executes proc coercion via cmdx_try" do
        proc_coercion = ->(value, _options) { value.to_s.reverse }
        registry.register(:proc_test, proc_coercion)

        result = registry.call(test_task, :proc_test, "hello")

        expect(result).to eq("olleh")
      end

      it "passes options to symbol/string/proc coercions" do
        option_method = ->(value, options) { "#{options[:prefix]}#{value}" }
        registry.register(:option_test, option_method)

        result = registry.call(test_task, :option_test, "test", prefix: "PRE_")

        expect(result).to eq("PRE_test")
      end
    end

    context "with error conditions" do
      it "raises UnknownCoercionError for unregistered type" do
        expect { registry.call(task, :unknown_type, "value") }.to raise_error(
          CMDx::UnknownCoercionError,
          "unknown coercion unknown_type"
        )
      end

      it "allows coercion errors to propagate" do
        expect { registry.call(task, :integer, "invalid") }.to raise_error(CMDx::CoercionError)
      end

      it "handles custom coercion errors" do
        error_coercion = Class.new do
          def self.call(_value, _options = {})
            raise StandardError, "custom error"
          end
        end

        registry.register(:error_test, error_coercion)

        expect { registry.call(task, :error_test, "value") }.to raise_error(StandardError, "custom error")
      end
    end

    context "with empty options" do
      it "handles calls without options" do
        result = registry.call(task, :string, 42)

        expect(result).to eq("42")
      end

      it "defaults to empty hash when options not provided" do
        allow(CMDx::Coercions::String).to receive(:call).and_call_original

        registry.call(task, :string, 42)

        expect(CMDx::Coercions::String).to have_received(:call).with(42, {})
      end
    end
  end

  describe "#registry" do
    it "exposes the internal registry hash" do
      expect(registry.registry).to be_a(Hash)
      expect(registry.registry.keys).to include(:string, :integer, :boolean)
    end

    it "allows direct access to registered coercions" do
      custom_coercion = ->(value, _options) { value.to_s }
      registry.register(:custom, custom_coercion)

      expect(registry.registry[:custom]).to eq(custom_coercion)
    end
  end
end
