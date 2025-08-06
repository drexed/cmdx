# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Numeric do
  subject(:validator) { described_class }

  describe ".call" do
    context "with within option" do
      let(:options) { { within: 1..10 } }

      context "when value is within range" do
        it "does not raise error for values within range" do
          expect { validator.call(1, options) }.not_to raise_error
          expect { validator.call(5, options) }.not_to raise_error
          expect { validator.call(10, options) }.not_to raise_error
        end
      end

      context "when value is not within range" do
        it "raises ValidationError with default message for below range" do
          expect { validator.call(0, options) }
            .to raise_error(CMDx::ValidationError, "must be within 1 and 10")
        end

        it "raises ValidationError with default message for above range" do
          expect { validator.call(11, options) }
            .to raise_error(CMDx::ValidationError, "must be within 1 and 10")
        end
      end

      context "with custom within_message" do
        let(:options) { { within: 1..10, within_message: "value must be between %<min>s and %<max>s" } }

        it "uses custom message with interpolation" do
          expect { validator.call(15, options) }
            .to raise_error(CMDx::ValidationError, "value must be between 1 and 10")
        end
      end

      context "with custom message" do
        let(:options) { { within: 1..10, message: "invalid range" } }

        it "uses custom message without interpolation" do
          expect { validator.call(15, options) }
            .to raise_error(CMDx::ValidationError, "invalid range")
        end
      end
    end

    context "with in option" do
      let(:options) { { in: 5..15 } }

      context "when value is in range" do
        it "does not raise error for values in range" do
          expect { validator.call(5, options) }.not_to raise_error
          expect { validator.call(10, options) }.not_to raise_error
          expect { validator.call(15, options) }.not_to raise_error
        end
      end

      context "when value is not in range" do
        it "raises ValidationError with default message" do
          expect { validator.call(4, options) }
            .to raise_error(CMDx::ValidationError, "must be within 5 and 15")
        end
      end

      context "with custom in_message" do
        let(:options) { { in: 5..15, in_message: "must be from %<min>s to %<max>s" } }

        it "uses custom in_message with interpolation" do
          expect { validator.call(20, options) }
            .to raise_error(CMDx::ValidationError, "must be from 5 to 15")
        end
      end
    end

    context "with not_within option" do
      let(:options) { { not_within: 5..10 } }

      context "when value is not within excluded range" do
        it "does not raise error for values outside range" do
          expect { validator.call(4, options) }.not_to raise_error
          expect { validator.call(11, options) }.not_to raise_error
          expect { validator.call(1, options) }.not_to raise_error
          expect { validator.call(100, options) }.not_to raise_error
        end
      end

      context "when value is within excluded range" do
        it "raises ValidationError with default message" do
          expect { validator.call(5, options) }
            .to raise_error(CMDx::ValidationError, "must not be within 5 and 10")
          expect { validator.call(7, options) }
            .to raise_error(CMDx::ValidationError, "must not be within 5 and 10")
          expect { validator.call(10, options) }
            .to raise_error(CMDx::ValidationError, "must not be within 5 and 10")
        end
      end

      context "with custom not_within_message" do
        let(:options) { { not_within: 5..10, not_within_message: "cannot be between %<min>s and %<max>s" } }

        it "uses custom not_within_message with interpolation" do
          expect { validator.call(8, options) }
            .to raise_error(CMDx::ValidationError, "cannot be between 5 and 10")
        end
      end
    end

    context "with not_in option" do
      let(:options) { { not_in: 20..30 } }

      context "when value is not in excluded range" do
        it "does not raise error for values outside range" do
          expect { validator.call(19, options) }.not_to raise_error
          expect { validator.call(31, options) }.not_to raise_error
        end
      end

      context "when value is in excluded range" do
        it "raises ValidationError with default message" do
          expect { validator.call(25, options) }
            .to raise_error(CMDx::ValidationError, "must not be within 20 and 30")
        end
      end

      context "with custom not_in_message" do
        let(:options) { { not_in: 20..30, not_in_message: "value forbidden between %<min>s and %<max>s" } }

        it "uses custom not_in_message with interpolation" do
          expect { validator.call(25, options) }
            .to raise_error(CMDx::ValidationError, "value forbidden between 20 and 30")
        end
      end
    end

    context "with min and max options" do
      let(:options) { { min: 5, max: 15 } }

      context "when value is between min and max" do
        it "does not raise error for values in range" do
          expect { validator.call(5, options) }.not_to raise_error
          expect { validator.call(10, options) }.not_to raise_error
          expect { validator.call(15, options) }.not_to raise_error
        end
      end

      context "when value is below min" do
        it "raises ValidationError with within message" do
          expect { validator.call(4, options) }
            .to raise_error(CMDx::ValidationError, "must be within 5 and 15")
        end
      end

      context "when value is above max" do
        it "raises ValidationError with within message" do
          expect { validator.call(16, options) }
            .to raise_error(CMDx::ValidationError, "must be within 5 and 15")
        end
      end
    end

    context "with min option only" do
      let(:options) { { min: 10 } }

      context "when value meets minimum" do
        it "does not raise error for values at or above minimum" do
          expect { validator.call(10, options) }.not_to raise_error
          expect { validator.call(15, options) }.not_to raise_error
          expect { validator.call(100, options) }.not_to raise_error
        end
      end

      context "when value is below minimum" do
        it "raises ValidationError with min message" do
          expect { validator.call(9, options) }
            .to raise_error(CMDx::ValidationError, "must be at least 10")
        end
      end

      context "with custom min_message" do
        let(:options) { { min: 10, min_message: "cannot be less than %<min>s" } }

        it "uses custom min_message with interpolation" do
          expect { validator.call(5, options) }
            .to raise_error(CMDx::ValidationError, "cannot be less than 10")
        end
      end
    end

    context "with max option only" do
      let(:options) { { max: 20 } }

      context "when value meets maximum" do
        it "does not raise error for values at or below maximum" do
          expect { validator.call(20, options) }.not_to raise_error
          expect { validator.call(15, options) }.not_to raise_error
          expect { validator.call(1, options) }.not_to raise_error
        end
      end

      context "when value exceeds maximum" do
        it "raises ValidationError with max message" do
          expect { validator.call(21, options) }
            .to raise_error(CMDx::ValidationError, "must be at most 20")
        end
      end

      context "with custom max_message" do
        let(:options) { { max: 20, max_message: "cannot exceed %<max>s" } }

        it "uses custom max_message with interpolation" do
          expect { validator.call(25, options) }
            .to raise_error(CMDx::ValidationError, "cannot exceed 20")
        end
      end
    end

    context "with is option" do
      let(:options) { { is: 42 } }

      context "when value equals expected value" do
        it "does not raise error for exact match" do
          expect { validator.call(42, options) }.not_to raise_error
        end
      end

      context "when value does not equal expected value" do
        it "raises ValidationError with is message" do
          expect { validator.call(41, options) }
            .to raise_error(CMDx::ValidationError, "must be 42")
          expect { validator.call(43, options) }
            .to raise_error(CMDx::ValidationError, "must be 42")
        end
      end

      context "with custom is_message" do
        let(:options) { { is: 42, is_message: "value must equal %<is>s" } }

        it "uses custom is_message with interpolation" do
          expect { validator.call(50, options) }
            .to raise_error(CMDx::ValidationError, "value must equal 42")
        end
      end
    end

    context "with is_not option" do
      let(:options) { { is_not: 13 } }

      context "when value does not equal forbidden value" do
        it "does not raise error for different values" do
          expect { validator.call(12, options) }.not_to raise_error
          expect { validator.call(14, options) }.not_to raise_error
          expect { validator.call(100, options) }.not_to raise_error
        end
      end

      context "when value equals forbidden value" do
        it "raises ValidationError with is_not message" do
          expect { validator.call(13, options) }
            .to raise_error(CMDx::ValidationError, "must not be 13")
        end
      end

      context "with custom is_not_message" do
        let(:options) { { is_not: 13, is_not_message: "cannot be %<is_not>s" } }

        it "uses custom is_not_message with interpolation" do
          expect { validator.call(13, options) }
            .to raise_error(CMDx::ValidationError, "cannot be 13")
        end
      end
    end

    context "with decimal values" do
      context "with within option" do
        let(:options) { { within: 1.5..10.5 } }

        it "validates decimal values correctly" do
          expect { validator.call(1.5, options) }.not_to raise_error
          expect { validator.call(5.7, options) }.not_to raise_error
          expect { validator.call(10.5, options) }.not_to raise_error

          expect { validator.call(1.4, options) }
            .to raise_error(CMDx::ValidationError, "must be within 1.5 and 10.5")
          expect { validator.call(10.6, options) }
            .to raise_error(CMDx::ValidationError, "must be within 1.5 and 10.5")
        end
      end
    end

    context "with negative values" do
      context "with min option" do
        let(:options) { { min: -10 } }

        it "validates negative values correctly" do
          expect { validator.call(-10, options) }.not_to raise_error
          expect { validator.call(-5, options) }.not_to raise_error
          expect { validator.call(0, options) }.not_to raise_error

          expect { validator.call(-11, options) }
            .to raise_error(CMDx::ValidationError, "must be at least -10")
        end
      end
    end

    context "with unknown options" do
      it "raises ArgumentError for unrecognized options" do
        expect { validator.call(5, { unknown: "option" }) }
          .to raise_error(ArgumentError, "unknown numeric validator options given")
      end
    end

    context "with empty options" do
      it "raises ArgumentError for empty options hash" do
        expect { validator.call(5, {}) }
          .to raise_error(ArgumentError, "unknown numeric validator options given")
      end
    end

    context "with global custom message" do
      context "when using within option" do
        let(:options) { { within: 1..10, message: "global error message" } }

        it "uses global message when specific message not provided" do
          expect { validator.call(15, options) }
            .to raise_error(CMDx::ValidationError, "global error message")
        end
      end

      context "when using min option" do
        let(:options) { { min: 10, message: "global min error" } }

        it "uses global message for min validation" do
          expect { validator.call(5, options) }
            .to raise_error(CMDx::ValidationError, "global min error")
        end
      end

      context "when using max option" do
        let(:options) { { max: 10, message: "global max error" } }

        it "uses global message for max validation" do
          expect { validator.call(15, options) }
            .to raise_error(CMDx::ValidationError, "global max error")
        end
      end

      context "when using is option" do
        let(:options) { { is: 42, message: "global is error" } }

        it "uses global message for is validation" do
          expect { validator.call(50, options) }
            .to raise_error(CMDx::ValidationError, "global is error")
        end
      end

      context "when using is_not option" do
        let(:options) { { is_not: 13, message: "global is_not error" } }

        it "uses global message for is_not validation" do
          expect { validator.call(13, options) }
            .to raise_error(CMDx::ValidationError, "global is_not error")
        end
      end

      context "when using not_within option" do
        let(:options) { { not_within: 5..10, message: "global not_within error" } }

        it "uses global message for not_within validation" do
          expect { validator.call(7, options) }
            .to raise_error(CMDx::ValidationError, "global not_within error")
        end
      end
    end
  end
end
