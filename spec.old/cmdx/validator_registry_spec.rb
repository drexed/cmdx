# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ValidatorRegistry do
  subject(:registry) { described_class.new }

  let(:task) { create_simple_task(name: "TestTask").new }

  describe ".new" do
    it "initializes with built-in validators" do
      expect(registry.registry).to include(
        exclusion: CMDx::Validators::Exclusion,
        format: CMDx::Validators::Format,
        inclusion: CMDx::Validators::Inclusion,
        length: CMDx::Validators::Length,
        numeric: CMDx::Validators::Numeric,
        presence: CMDx::Validators::Presence
      )
    end

    it "creates a hash registry" do
      expect(registry.registry).to be_a(Hash)
    end
  end

  describe "#register" do
    it "registers a validator class" do
      validator_class = Class.new do
        def self.call(value, _options)
          value.length > 5
        end
      end

      registry.register(:custom, validator_class)

      expect(registry.registry[:custom]).to eq(validator_class)
    end

    it "registers a proc validator" do
      validator_proc = ->(value, _options) { value.length > 3 }
      registry.register(:proc_validator, validator_proc)

      expect(registry.registry[:proc_validator]).to eq(validator_proc)
    end

    it "registers a symbol validator" do
      registry.register(:symbol_validator, :validate_method)

      expect(registry.registry[:symbol_validator]).to eq(:validate_method)
    end

    it "registers a string validator" do
      registry.register(:string_validator, "validate_method")

      expect(registry.registry[:string_validator]).to eq("validate_method")
    end

    it "returns self for method chaining" do
      result = registry.register(:first, :method1)
                       .register(:second, :method2)

      expect(result).to eq(registry)
      expect(registry.registry[:first]).to eq(:method1)
      expect(registry.registry[:second]).to eq(:method2)
    end

    it "overwrites existing validator with same type" do
      registry.register(:test, :original)
      registry.register(:test, :updated)

      expect(registry.registry[:test]).to eq(:updated)
    end
  end

  describe "#call" do
    context "with unknown validator type" do
      it "raises UnknownValidatorError" do
        expect { registry.call(task, :unknown, "value") }.to raise_error(
          CMDx::UnknownValidatorError,
          "unknown validator unknown"
        )
      end
    end

    context "with conditional execution" do
      let(:conditional_task) do
        create_task_class(name: "ConditionalTask") do
          attr_accessor :should_validate

          def call
            context.executed = true
          end
        end.new
      end

      it "executes validator when condition is true" do
        conditional_task.should_validate = true
        registry.register(:test, ->(value, _opts) { value })

        result = registry.call(conditional_task, :test, "value", if: :should_validate)

        expect(result).to eq("value")
      end

      it "skips validator when condition is false" do
        conditional_task.should_validate = false
        registry.register(:test, ->(value, _opts) { value })

        result = registry.call(conditional_task, :test, "value", if: :should_validate)

        expect(result).to be_nil
      end

      it "executes validator when no conditions specified" do
        registry.register(:test, ->(value, _opts) { value })

        result = registry.call(task, :test, "value", {})

        expect(result).to eq("value")
      end
    end

    context "with built-in validators" do
      it "calls built-in validator class" do
        expect(CMDx::Validators::Presence).to receive(:call).with("", {})

        registry.call(task, :presence, "", {})
      end

      it "executes presence validation successfully" do
        expect { registry.call(task, :presence, "value", {}) }.not_to raise_error
      end

      it "executes format validation successfully" do
        expect { registry.call(task, :format, "test@example.com", { with: /@/ }) }.not_to raise_error
      end
    end

    context "with custom symbol validators" do
      let(:validator_task) do
        create_task_class(name: "ValidatorTask") do
          def validate_email(value, _options)
            value.include?("@") ? nil : "invalid email"
          end

          def call
            context.executed = true
          end
        end.new
      end

      it "executes symbol validator via cmdx_try" do
        registry.register(:email, :validate_email)

        result = registry.call(validator_task, :email, "test@example.com", {})

        expect(result).to be_nil
      end

      it "passes value and options to symbol validator" do
        registry.register(:custom, :validate_email)

        expect(validator_task).to receive(:validate_email).with("value", { strict: true })

        registry.call(validator_task, :custom, "value", { strict: true })
      end
    end

    context "with custom string validators" do
      let(:validator_task) do
        create_task_class(name: "ValidatorTask") do
          def validate_string_method(value, _options)
            value.length > 5 ? nil : "too short"
          end

          def call
            context.executed = true
          end
        end.new
      end

      it "executes string validator via cmdx_try" do
        registry.register(:string_test, "validate_string_method")

        result = registry.call(validator_task, :string_test, "long enough", {})

        expect(result).to be_nil
      end
    end

    context "with custom proc validators" do
      it "executes proc validator" do
        validator_proc = ->(value, _options) { value.length > 3 ? nil : "too short" }
        registry.register(:proc_test, validator_proc)

        result = registry.call(task, :proc_test, "long", {})

        expect(result).to be_nil
      end

      it "passes value and options to proc validator" do
        validator_proc = lambda { |value, options|
          options[:multiplier] ? value * options[:multiplier] : value
        }
        registry.register(:multiplier, validator_proc)

        result = registry.call(task, :multiplier, 5, { multiplier: 3 })

        expect(result).to eq(15)
      end

      it "handles proc validator with task context" do
        validator_proc = ->(value, _options) { value.upcase }
        registry.register(:upcase, validator_proc)

        result = registry.call(task, :upcase, "hello", {})

        expect(result).to eq("HELLO")
      end
    end

    context "with custom class validators" do
      let(:custom_validator) do
        Class.new do
          def self.call(value, options)
            return nil if value.length >= (options[:minimum] || 0)

            "too short"
          end
        end
      end

      it "executes class validator" do
        registry.register(:class_test, custom_validator)

        result = registry.call(task, :class_test, "test", { minimum: 3 })

        expect(result).to be_nil
      end

      it "passes value and options to class validator" do
        registry.register(:length_check, custom_validator)

        result = registry.call(task, :length_check, "hi", { minimum: 5 })

        expect(result).to eq("too short")
      end
    end

    context "with callable objects" do
      let(:callable_validator) do
        double("CallableValidator").tap do |validator|
          allow(validator).to receive(:call).and_return("validation result")
        end
      end

      it "executes callable object" do
        registry.register(:callable, callable_validator)

        result = registry.call(task, :callable, "value", { option: "test" })

        expect(callable_validator).to have_received(:call).with("value", { option: "test" })
        expect(result).to eq("validation result")
      end
    end

    context "with complex conditional scenarios" do
      let(:complex_task) do
        create_task_class(name: "ComplexTask") do
          attr_accessor :validation_enabled, :strict_mode

          def call
            context.executed = true
          end
        end.new
      end

      it "handles if and unless conditions together" do
        complex_task.validation_enabled = true
        complex_task.strict_mode = false
        registry.register(:complex, ->(_v, _o) { "validated" })

        result = registry.call(complex_task, :complex, "value", {
                                 if: :validation_enabled,
                                 unless: :strict_mode
                               })

        expect(result).to eq("validated")
      end

      it "skips when if condition is false" do
        complex_task.validation_enabled = false
        registry.register(:complex, ->(_v, _o) { "validated" })

        result = registry.call(complex_task, :complex, "value", { if: :validation_enabled })

        expect(result).to be_nil
      end

      it "skips when unless condition is true" do
        complex_task.strict_mode = true
        registry.register(:complex, ->(_v, _o) { "validated" })

        result = registry.call(complex_task, :complex, "value", { unless: :strict_mode })

        expect(result).to be_nil
      end
    end
  end
end
