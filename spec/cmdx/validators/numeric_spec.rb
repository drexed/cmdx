# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Numeric do
  subject(:validator) { described_class.call(value, options) }

  let(:validator_key) { :numeric }
  let(:base_options) { { numeric: {} } }
  let(:options) { base_options }
  let(:value) { 5 }

  # Parametric validator configuration
  let(:unsupported_options) { { numeric: { between: 1..5 } } }
  let(:expected_unsupported_message) { "no known numeric validator options given" }

  # Minimum constraint configuration
  let(:min_constraint_options) { { numeric: { min: 1 } } }
  let(:min_valid_value) { 5 }
  let(:min_invalid_value) { 0 }
  let(:expected_min_message) { "must be at least 1" }
  let(:custom_interpolated_message) { "custom message %{min}" }
  let(:expected_interpolated_message) { "custom message 1" }

  # Maximum constraint configuration
  let(:max_constraint_options) { { numeric: { max: 5 } } }
  let(:max_valid_value) { 5 }
  let(:max_invalid_value) { 6 }
  let(:expected_max_message) { "must be at most 5" }

  it_behaves_like "a parametric validator"

  context "when using combined min and max constraints" do
    let(:options) { { numeric: { min: 1, max: 5 } } }

    context "when value is within range" do
      let(:value) { 3 }

      it "returns nil without raising error" do
        expect(validator).to be_nil
      end
    end

    context "when value is outside range" do
      let(:value) { 6 }

      it "raises ValidationError with combined message" do
        expect { validator }.to raise_error(CMDx::ValidationError, "must be within 1 and 5")
      end
    end

    context "with custom message interpolation" do
      let(:options) { { numeric: { min: 1, max: 5, message: "custom message %{min} and %{max}" } } }
      let(:value) { 6 }

      it "raises ValidationError with interpolated message" do
        expect { validator }.to raise_error(CMDx::ValidationError, "custom message 1 and 5")
      end
    end
  end

  context "when using within constraint" do
    let(:options) { { numeric: { within: (1..5) } } }

    context "when value is within range" do
      let(:value) { 3 }

      it "returns nil without raising error" do
        expect(validator).to be_nil
      end
    end

    context "when value is outside range" do
      let(:value) { 6 }

      it "raises ValidationError with within message" do
        expect { validator }.to raise_error(CMDx::ValidationError, "must be within 1 and 5")
      end
    end

    context "with custom message interpolation" do
      let(:options) { { numeric: { within: (1..5), message: "custom message %{min} and %{max}" } } }
      let(:value) { 6 }

      it "raises ValidationError with interpolated message" do
        expect { validator }.to raise_error(CMDx::ValidationError, "custom message 1 and 5")
      end
    end
  end

  context "when using not_within constraint" do
    let(:options) { { numeric: { not_within: (1..5) } } }

    context "when value is outside excluded range" do
      let(:value) { 6 }

      it "returns nil without raising error" do
        expect(validator).to be_nil
      end
    end

    context "when value is within excluded range" do
      let(:value) { 3 }

      it "raises ValidationError with not_within message" do
        expect { validator }.to raise_error(CMDx::ValidationError, "must not be within 1 and 5")
      end
    end

    context "with custom message interpolation" do
      let(:options) { { numeric: { not_within: (1..5), message: "custom message %{min} and %{max}" } } }
      let(:value) { 3 }

      it "raises ValidationError with interpolated message" do
        expect { validator }.to raise_error(CMDx::ValidationError, "custom message 1 and 5")
      end
    end
  end

  context "when using exact value constraint" do
    let(:options) { { numeric: { is: 5 } } }

    context "when value matches exactly" do
      let(:value) { 5 }

      it "returns nil without raising error" do
        expect(validator).to be_nil
      end
    end

    context "when value does not match" do
      let(:value) { 6 }

      it "raises ValidationError with exact value message" do
        expect { validator }.to raise_error(CMDx::ValidationError, "must be 5")
      end
    end

    context "with custom message interpolation" do
      let(:options) { { numeric: { is: 5, message: "custom message %{is}" } } }
      let(:value) { 6 }

      it "raises ValidationError with interpolated message" do
        expect { validator }.to raise_error(CMDx::ValidationError, "custom message 5")
      end
    end
  end

  context "when using is_not constraint" do
    let(:options) { { numeric: { is_not: 5 } } }

    context "when value is different" do
      let(:value) { 6 }

      it "returns nil without raising error" do
        expect(validator).to be_nil
      end
    end

    context "when value matches excluded value" do
      let(:value) { 5 }

      it "raises ValidationError with is_not message" do
        expect { validator }.to raise_error(CMDx::ValidationError, "must not be 5")
      end
    end

    context "with custom message interpolation" do
      let(:options) { { numeric: { is_not: 5, message: "custom message %{is_not}" } } }
      let(:value) { 5 }

      it "raises ValidationError with interpolated message" do
        expect { validator }.to raise_error(CMDx::ValidationError, "custom message 5")
      end
    end
  end
end
