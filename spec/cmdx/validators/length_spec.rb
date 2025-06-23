# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Length do
  subject(:validator) { described_class.call(value, options) }

  let(:validator_key) { :length }
  let(:base_options) { { length: {} } }
  let(:options) { base_options }
  let(:valid_value) { "abc12" }
  let(:value) { valid_value }

  # Parametric validator configuration
  let(:unsupported_options) { { length: { between: 1..5 } } }
  let(:expected_unsupported_message) { "no known length validator options given" }

  # Minimum constraint configuration
  let(:min_constraint_options) { { length: { min: 1 } } }
  let(:min_valid_value) { "abc12" }
  let(:min_invalid_value) { "" }
  let(:expected_min_message) { "length must be at least 1" }
  let(:custom_interpolated_message) { "custom message %{min}" }
  let(:expected_interpolated_message) { "custom message 1" }

  # Maximum constraint configuration
  let(:max_constraint_options) { { length: { max: 5 } } }
  let(:max_valid_value) { "abc12" }
  let(:max_invalid_value) { "abc123" }
  let(:expected_max_message) { "length must be at most 5" }

  it_behaves_like "a parametric validator"

  context "when using combined min and max constraints" do
    let(:options) { { length: { min: 1, max: 5 } } }

    context "when length is within range" do
      let(:value) { "abc12" }

      it "returns nil without raising error" do
        expect(validator).to be_nil
      end
    end

    context "when length is outside range" do
      let(:value) { "abc123" }

      it "raises ValidationError with combined message" do
        expect { validator }.to raise_error(CMDx::ValidationError, "length must be within 1 and 5")
      end
    end

    context "with custom message interpolation" do
      let(:options) { { length: { min: 1, max: 5, message: "custom message %{min} and %{max}" } } }
      let(:value) { "abc123" }

      it "raises ValidationError with interpolated message" do
        expect { validator }.to raise_error(CMDx::ValidationError, "custom message 1 and 5")
      end
    end
  end

  context "when using within constraint" do
    let(:options) { { length: { within: (1..5) } } }

    context "when length is within range" do
      let(:value) { "abc12" }

      it "returns nil without raising error" do
        expect(validator).to be_nil
      end
    end

    context "when length is outside range" do
      let(:value) { "abc123" }

      it "raises ValidationError with within message" do
        expect { validator }.to raise_error(CMDx::ValidationError, "length must be within 1 and 5")
      end
    end

    context "with custom message interpolation" do
      let(:options) { { length: { within: (1..5), message: "custom message %{min} and %{max}" } } }
      let(:value) { "abc123" }

      it "raises ValidationError with interpolated message" do
        expect { validator }.to raise_error(CMDx::ValidationError, "custom message 1 and 5")
      end
    end
  end

  context "when using not_within constraint" do
    let(:options) { { length: { not_within: (1..5) } } }

    context "when length is outside excluded range" do
      let(:value) { "abc123" }

      it "returns nil without raising error" do
        expect(validator).to be_nil
      end
    end

    context "when length is within excluded range" do
      let(:value) { "abc12" }

      it "raises ValidationError with not_within message" do
        expect { validator }.to raise_error(CMDx::ValidationError, "length must not be within 1 and 5")
      end
    end

    context "with custom message interpolation" do
      let(:options) { { length: { not_within: (1..5), message: "custom message %{min} and %{max}" } } }
      let(:value) { "abc12" }

      it "raises ValidationError with interpolated message" do
        expect { validator }.to raise_error(CMDx::ValidationError, "custom message 1 and 5")
      end
    end
  end

  context "when using exact length constraint" do
    let(:options) { { length: { is: 5 } } }

    context "when length matches exactly" do
      let(:value) { "abc12" }

      it "returns nil without raising error" do
        expect(validator).to be_nil
      end
    end

    context "when length does not match" do
      let(:value) { "abc123" }

      it "raises ValidationError with exact length message" do
        expect { validator }.to raise_error(CMDx::ValidationError, "length must be 5")
      end
    end

    context "with custom message interpolation" do
      let(:options) { { length: { is: 5, message: "custom message %{is}" } } }
      let(:value) { "abc123" }

      it "raises ValidationError with interpolated message" do
        expect { validator }.to raise_error(CMDx::ValidationError, "custom message 5")
      end
    end
  end

  context "when using not_is constraint" do
    let(:options) { { length: { is_not: 5 } } }

    context "when length is different" do
      let(:value) { "abc123" }

      it "returns nil without raising error" do
        expect(validator).to be_nil
      end
    end

    context "when length matches excluded value" do
      let(:value) { "abc12" }

      it "raises ValidationError with not_is message" do
        expect { validator }.to raise_error(CMDx::ValidationError, "length must not be 5")
      end
    end

    context "with custom message interpolation" do
      let(:options) { { length: { is_not: 5, message: "custom message %{is_not}" } } }
      let(:value) { "abc12" }

      it "raises ValidationError with interpolated message" do
        expect { validator }.to raise_error(CMDx::ValidationError, "custom message 5")
      end
    end
  end
end
