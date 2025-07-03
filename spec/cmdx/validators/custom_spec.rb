# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Custom do
  let(:valid_validator) { double("ValidValidator", call: true) }
  let(:invalid_validator) { double("InvalidValidator", call: false) }
  let(:options_validator) { ->(value, opts) { value >= opts.dig(:custom, :minimum) } }
  let(:class_validator) { double("ClassValidator", call: true) }

  describe "#call" do
    context "with successful validation" do
      it "passes when validator returns truthy value" do
        expect { described_class.call(15, custom: { validator: valid_validator }) }.not_to raise_error
      end

      it "passes when validator returns true" do
        allow(class_validator).to receive(:call).and_return(true)

        expect { described_class.call(20, custom: { validator: class_validator }) }.not_to raise_error
      end

      it "passes when validator returns non-false value" do
        validator = ->(_value, _options) { "truthy string" }

        expect { described_class.call(5, custom: { validator: validator }) }.not_to raise_error
      end

      it "forwards value and options to validator" do
        allow(valid_validator).to receive(:call).and_return(true)
        options = { custom: { validator: valid_validator, minimum: 5 } }

        described_class.call(15, options)

        expect(valid_validator).to have_received(:call).with(15, options)
      end
    end

    context "with failed validation" do
      it "raises ValidationError when validator returns false" do
        allow(invalid_validator).to receive(:call).and_return(false)

        expect do
          described_class.call(5, custom: { validator: invalid_validator })
        end.to raise_error(CMDx::ValidationError, "is not valid")
      end

      it "raises ValidationError when validator returns nil" do
        validator = ->(value, options) {}

        expect do
          described_class.call(10, custom: { validator: validator })
        end.to raise_error(CMDx::ValidationError, "is not valid")
      end

      it "raises ValidationError when validator returns falsy value" do
        validator = ->(_value, _options) { false }

        expect do
          described_class.call(8, custom: { validator: validator })
        end.to raise_error(CMDx::ValidationError, "is not valid")
      end

      it "uses custom message when provided" do
        allow(invalid_validator).to receive(:call).and_return(false)

        expect do
          described_class.call(3, custom: { validator: invalid_validator, message: "custom error" })
        end.to raise_error(CMDx::ValidationError, "custom error")
      end

      it "uses I18n translation when available" do
        allow(I18n).to receive(:t).with("cmdx.validators.custom", default: "is not valid").and_return("translated error")
        allow(invalid_validator).to receive(:call).and_return(false)

        expect do
          described_class.call(7, custom: { validator: invalid_validator })
        end.to raise_error(CMDx::ValidationError, "translated error")
      end
    end

    context "with validator using options" do
      it "passes options to validator for complex validation" do
        options = { custom: { validator: options_validator, minimum: 15 } }

        expect { described_class.call(20, options) }.not_to raise_error
      end

      it "fails when options-based validation fails" do
        options = { custom: { validator: options_validator, minimum: 25 } }

        expect do
          described_class.call(20, options)
        end.to raise_error(CMDx::ValidationError)
      end

      it "accesses nested custom options in validator" do
        validator = ->(value, opts) { value.length >= opts.dig(:custom, :min_length) }
        options = { custom: { validator: validator, min_length: 5 } }

        expect { described_class.call("hello", options) }.not_to raise_error
      end
    end

    context "with class-based validators" do
      it "calls class validator with correct arguments" do
        allow(class_validator).to receive(:call).and_return(true)
        options = { custom: { validator: class_validator } }

        described_class.call(42, options)

        expect(class_validator).to have_received(:call).with(42, options)
      end

      it "handles class validator failure" do
        allow(class_validator).to receive(:call).and_return(false)

        expect do
          described_class.call(10, custom: { validator: class_validator })
        end.to raise_error(CMDx::ValidationError, "is not valid")
      end
    end

    context "with different value types" do
      it "validates string values" do
        validator = ->(value, _options) { value.include?("test") }

        expect { described_class.call("test string", custom: { validator: validator }) }.not_to raise_error
      end

      it "validates array values" do
        validator = ->(value, _options) { value.length == 3 }

        expect { described_class.call([1, 2, 3], custom: { validator: validator }) }.not_to raise_error
      end

      it "validates hash values" do
        validator = ->(value, _options) { value.key?(:name) }

        expect { described_class.call({ name: "test" }, custom: { validator: validator }) }.not_to raise_error
      end

      it "validates nil values" do
        validator = ->(value, _options) { value.nil? }

        expect { described_class.call(nil, custom: { validator: validator }) }.not_to raise_error
      end
    end
  end
end
