# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Numeric do
  describe "#call" do
    context "with within range validation" do
      it "passes when value is within range" do
        expect { described_class.call(50, numeric: { within: 1..100 }) }.not_to raise_error
      end

      it "passes when float value is within range" do
        expect { described_class.call(2.5, numeric: { within: 1.0..5.0 }) }.not_to raise_error
      end

      it "passes when value is at range boundaries" do
        expect { described_class.call(1, numeric: { within: 1..100 }) }.not_to raise_error
        expect { described_class.call(100, numeric: { within: 1..100 }) }.not_to raise_error
      end

      it "raises ValidationError when value is below range" do
        expect do
          described_class.call(0, numeric: { within: 1..100 })
        end.to raise_error(CMDx::ValidationError, "must be within 1 and 100")
      end

      it "raises ValidationError when value is above range" do
        expect do
          described_class.call(150, numeric: { within: 1..100 })
        end.to raise_error(CMDx::ValidationError, "must be within 1 and 100")
      end
    end

    context "with in range validation" do
      it "passes when value is in range" do
        expect { described_class.call(25, numeric: { in: 10..50 }) }.not_to raise_error
      end

      it "raises ValidationError when value is not in range" do
        expect do
          described_class.call(5, numeric: { in: 10..50 })
        end.to raise_error(CMDx::ValidationError, "must be within 10 and 50")
      end
    end

    context "with not_within range validation" do
      it "passes when value is not within forbidden range" do
        expect { described_class.call(5, numeric: { not_within: 10..20 }) }.not_to raise_error
      end

      it "passes when value is outside forbidden boundaries" do
        expect { described_class.call(9, numeric: { not_within: 10..20 }) }.not_to raise_error
        expect { described_class.call(21, numeric: { not_within: 10..20 }) }.not_to raise_error
      end

      it "raises ValidationError when value is within forbidden range" do
        expect do
          described_class.call(15, numeric: { not_within: 10..20 })
        end.to raise_error(CMDx::ValidationError, "must not be within 10 and 20")
      end
    end

    context "with not_in range validation" do
      it "passes when value is not in forbidden range" do
        expect { described_class.call(25, numeric: { not_in: 10..20 }) }.not_to raise_error
      end

      it "raises ValidationError when value is in forbidden range" do
        expect do
          described_class.call(15, numeric: { not_in: 10..20 })
        end.to raise_error(CMDx::ValidationError, "must not be within 10 and 20")
      end
    end

    context "with minimum value validation" do
      it "passes when value meets minimum" do
        expect { described_class.call(25, numeric: { min: 18 }) }.not_to raise_error
      end

      it "passes when value exceeds minimum" do
        expect { described_class.call(30, numeric: { min: 18 }) }.not_to raise_error
      end

      it "passes when value equals minimum" do
        expect { described_class.call(18, numeric: { min: 18 }) }.not_to raise_error
      end

      it "raises ValidationError when value is below minimum" do
        expect do
          described_class.call(15, numeric: { min: 18 })
        end.to raise_error(CMDx::ValidationError, "must be at least 18")
      end
    end

    context "with maximum value validation" do
      it "passes when value is under maximum" do
        expect { described_class.call(50, numeric: { max: 100 }) }.not_to raise_error
      end

      it "passes when value equals maximum" do
        expect { described_class.call(100, numeric: { max: 100 }) }.not_to raise_error
      end

      it "raises ValidationError when value exceeds maximum" do
        expect do
          described_class.call(150, numeric: { max: 100 })
        end.to raise_error(CMDx::ValidationError, "must be at most 100")
      end
    end

    context "with combined min and max validation" do
      it "passes when value is between min and max" do
        expect { described_class.call(3.5, numeric: { min: 1.0, max: 5.0 }) }.not_to raise_error
      end

      it "passes when value equals boundaries" do
        expect { described_class.call(1.0, numeric: { min: 1.0, max: 5.0 }) }.not_to raise_error
        expect { described_class.call(5.0, numeric: { min: 1.0, max: 5.0 }) }.not_to raise_error
      end

      it "raises ValidationError when value is below minimum" do
        expect do
          described_class.call(0.5, numeric: { min: 1.0, max: 5.0 })
        end.to raise_error(CMDx::ValidationError, "must be within 1.0 and 5.0")
      end

      it "raises ValidationError when value is above maximum" do
        expect do
          described_class.call(6.0, numeric: { min: 1.0, max: 5.0 })
        end.to raise_error(CMDx::ValidationError, "must be within 1.0 and 5.0")
      end
    end

    context "with exact value validation" do
      it "passes when value matches exactly" do
        expect { described_class.call(42, numeric: { is: 42 }) }.not_to raise_error
      end

      it "passes when float value matches exactly" do
        expect { described_class.call(3.14, numeric: { is: 3.14 }) }.not_to raise_error
      end

      it "raises ValidationError when value does not match" do
        expect do
          described_class.call(41, numeric: { is: 42 })
        end.to raise_error(CMDx::ValidationError, "must be 42")
      end

      it "raises ValidationError when value is close but not exact" do
        expect do
          described_class.call(3.141, numeric: { is: 3.14 })
        end.to raise_error(CMDx::ValidationError, "must be 3.14")
      end
    end

    context "with forbidden exact value validation" do
      it "passes when value does not match forbidden value" do
        expect { described_class.call(5, numeric: { is_not: 0 }) }.not_to raise_error
      end

      it "passes when value is different from forbidden value" do
        expect { described_class.call(1, numeric: { is_not: 0 }) }.not_to raise_error
        expect { described_class.call(-1, numeric: { is_not: 0 }) }.not_to raise_error
      end

      it "raises ValidationError when value matches forbidden value" do
        expect do
          described_class.call(0, numeric: { is_not: 0 })
        end.to raise_error(CMDx::ValidationError, "must not be 0")
      end
    end

    context "with custom error messages" do
      it "uses custom within_message" do
        expect do
          described_class.call(150, numeric: {
                                 within: 1..100,
                                 within_message: "must be between %{min} and %{max} items"
                               })
        end.to raise_error(CMDx::ValidationError, "must be between 1 and 100 items")
      end

      it "uses custom in_message" do
        expect do
          described_class.call(5, numeric: {
                                 in: 10..50,
                                 in_message: "should be from %{min} to %{max}"
                               })
        end.to raise_error(CMDx::ValidationError, "should be from 10 to 50")
      end

      it "uses custom not_within_message" do
        expect do
          described_class.call(15, numeric: {
                                 not_within: 10..20,
                                 not_within_message: "cannot be between %{min} and %{max}"
                               })
        end.to raise_error(CMDx::ValidationError, "cannot be between 10 and 20")
      end

      it "uses custom min_message" do
        expect do
          described_class.call(15, numeric: {
                                 min: 18,
                                 min_message: "must be at least %{min} years old"
                               })
        end.to raise_error(CMDx::ValidationError, "must be at least 18 years old")
      end

      it "uses custom max_message" do
        expect do
          described_class.call(150, numeric: {
                                 max: 100,
                                 max_message: "cannot exceed %{max} points"
                               })
        end.to raise_error(CMDx::ValidationError, "cannot exceed 100 points")
      end

      it "uses custom is_message" do
        expect do
          described_class.call(41, numeric: {
                                 is: 42,
                                 is_message: "must be exactly %{is}"
                               })
        end.to raise_error(CMDx::ValidationError, "must be exactly 42")
      end

      it "uses custom is_not_message" do
        expect do
          described_class.call(0, numeric: {
                                 is_not: 0,
                                 is_not_message: "cannot be %{is_not}"
                               })
        end.to raise_error(CMDx::ValidationError, "cannot be 0")
      end

      it "uses general message override" do
        expect do
          described_class.call(5, numeric: {
                                 min: 10,
                                 message: "general numeric error"
                               })
        end.to raise_error(CMDx::ValidationError, "general numeric error")
      end

      it "uses I18n translation when available" do
        allow(I18n).to receive(:t).with("cmdx.validators.numeric.min", min: 10, default: "must be at least 10").and_return("translated min error")

        expect do
          described_class.call(5, numeric: { min: 10 })
        end.to raise_error(CMDx::ValidationError, "translated min error")
      end
    end

    context "with different numeric types" do
      it "validates integer values" do
        expect { described_class.call(42, numeric: { min: 1 }) }.not_to raise_error
      end

      it "validates float values" do
        expect { described_class.call(19.99, numeric: { max: 20.0 }) }.not_to raise_error
      end

      it "validates negative integers" do
        expect { described_class.call(-5, numeric: { within: -10..0 }) }.not_to raise_error
      end

      it "validates negative floats" do
        expect { described_class.call(-2.5, numeric: { min: -5.0 }) }.not_to raise_error
      end

      it "validates zero" do
        expect { described_class.call(0, numeric: { within: -1..1 }) }.not_to raise_error
      end

      it "validates large numbers" do
        expect { described_class.call(1_000_000, numeric: { min: 500_000 }) }.not_to raise_error
      end

      it "validates decimal values" do
        expect { described_class.call(BigDecimal("3.14159"), numeric: { within: 3..4 }) }.not_to raise_error
      end

      it "validates rational values" do
        expect { described_class.call(Rational(3, 4), numeric: { within: 0..1 }) }.not_to raise_error
      end
    end

    context "with edge cases" do
      it "handles zero as minimum" do
        expect { described_class.call(5, numeric: { min: 0 }) }.not_to raise_error
      end

      it "handles negative ranges" do
        expect { described_class.call(-5, numeric: { within: -10..-1 }) }.not_to raise_error
      end

      it "handles fractional boundaries" do
        expect { described_class.call(2.5, numeric: { within: 2.1..2.9 }) }.not_to raise_error
      end

      it "handles exclusive ranges" do
        expect { described_class.call(5, numeric: { within: 1...10 }) }.not_to raise_error
      end

      it "raises ValidationError for exclusive range boundary" do
        expect do
          described_class.call(10, numeric: { within: 1...10 })
        end.to raise_error(CMDx::ValidationError, "must be within 1 and 10")
      end

      it "handles very small numbers" do
        expect { described_class.call(0.0001, numeric: { min: 0 }) }.not_to raise_error
      end

      it "handles very large numbers" do
        expect { described_class.call(Float::INFINITY, numeric: { min: 1000 }) }.not_to raise_error
      end
    end

    context "with invalid options" do
      it "raises ArgumentError when no valid options provided" do
        expect do
          described_class.call(42, numeric: {})
        end.to raise_error(ArgumentError, "no known numeric validator options given")
      end

      it "raises ArgumentError when only invalid options provided" do
        expect do
          described_class.call(42, numeric: { invalid: 5 })
        end.to raise_error(ArgumentError, "no known numeric validator options given")
      end
    end
  end
end
