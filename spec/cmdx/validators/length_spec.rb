# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Length, type: :unit do
  subject(:validator) { described_class }

  describe ".call" do
    context "with :within option" do
      let(:options) { { within: (3..10) } }

      context "when value length is within range" do
        it "does not raise error for valid lengths" do
          expect { validator.call("abc", options) }.not_to raise_error
          expect { validator.call("test", options) }.not_to raise_error
          expect { validator.call("1234567890", options) }.not_to raise_error
        end
      end

      context "when value length is outside range" do
        it "raises ValidationError for lengths below minimum" do
          expect { validator.call("ab", options) }
            .to raise_error(CMDx::ValidationError, "length must be within 3 and 10")
        end

        it "raises ValidationError for lengths above maximum" do
          expect { validator.call("12345678901", options) }
            .to raise_error(CMDx::ValidationError, "length must be within 3 and 10")
        end
      end

      context "with custom :within_message" do
        let(:options) { { within: (5..15), within_message: "must be between %<min>s and %<max>s characters" } }

        it "uses custom message with interpolation" do
          expect { validator.call("abc", options) }
            .to raise_error(CMDx::ValidationError, "must be between 5 and 15 characters")
        end
      end

      context "with custom :message" do
        let(:options) { { within: (2..5), message: "invalid length" } }

        it "uses custom message" do
          expect { validator.call("toolong", options) }
            .to raise_error(CMDx::ValidationError, "invalid length")
        end
      end
    end

    context "with :not_within option" do
      let(:options) { { not_within: (5..8) } }

      context "when value length is outside forbidden range" do
        it "does not raise error for valid lengths" do
          expect { validator.call("abc", options) }.not_to raise_error
          expect { validator.call("123456789", options) }.not_to raise_error
        end
      end

      context "when value length is within forbidden range" do
        it "raises ValidationError for forbidden lengths" do
          expect { validator.call("12345", options) }
            .to raise_error(CMDx::ValidationError, "length must not be within 5 and 8")

          expect { validator.call("123456", options) }
            .to raise_error(CMDx::ValidationError, "length must not be within 5 and 8")
        end
      end

      context "with custom :not_within_message" do
        let(:options) { { not_within: (3..6), not_within_message: "cannot be %<min>s-%<max>s chars" } }

        it "uses custom message with interpolation" do
          expect { validator.call("test", options) }
            .to raise_error(CMDx::ValidationError, "cannot be 3-6 chars")
        end
      end
    end

    context "with :in option" do
      let(:options) { { in: (2..7) } }

      context "when value length is in range" do
        it "does not raise error for valid lengths" do
          expect { validator.call("ab", options) }.not_to raise_error
          expect { validator.call("1234567", options) }.not_to raise_error
        end
      end

      context "when value length is outside range" do
        it "raises ValidationError for invalid lengths" do
          expect { validator.call("a", options) }
            .to raise_error(CMDx::ValidationError, "length must be within 2 and 7")

          expect { validator.call("12345678", options) }
            .to raise_error(CMDx::ValidationError, "length must be within 2 and 7")
        end
      end

      context "with custom :in_message" do
        let(:options) { { in: (1..3), in_message: "should be %<min>s to %<max>s long" } }

        it "uses custom message with interpolation" do
          expect { validator.call("toolong", options) }
            .to raise_error(CMDx::ValidationError, "should be 1 to 3 long")
        end
      end
    end

    context "with :not_in option" do
      let(:options) { { not_in: (4..6) } }

      context "when value length is outside forbidden range" do
        it "does not raise error for valid lengths" do
          expect { validator.call("abc", options) }.not_to raise_error
          expect { validator.call("1234567", options) }.not_to raise_error
        end
      end

      context "when value length is in forbidden range" do
        it "raises ValidationError for forbidden lengths" do
          expect { validator.call("1234", options) }
            .to raise_error(CMDx::ValidationError, "length must not be within 4 and 6")
        end
      end

      context "with custom :not_in_message" do
        let(:options) { { not_in: (2..4), not_in_message: "forbidden range %<min>s-%<max>s" } }

        it "uses custom message with interpolation" do
          expect { validator.call("abc", options) }
            .to raise_error(CMDx::ValidationError, "forbidden range 2-4")
        end
      end
    end

    context "with :min and :max options" do
      let(:options) { { min: 3, max: 8 } }

      context "when value length is within bounds" do
        it "does not raise error for valid lengths" do
          expect { validator.call("abc", options) }.not_to raise_error
          expect { validator.call("test", options) }.not_to raise_error
          expect { validator.call("12345678", options) }.not_to raise_error
        end
      end

      context "when value length is outside bounds" do
        it "raises ValidationError for lengths below minimum" do
          expect { validator.call("ab", options) }
            .to raise_error(CMDx::ValidationError, "length must be within 3 and 8")
        end

        it "raises ValidationError for lengths above maximum" do
          expect { validator.call("123456789", options) }
            .to raise_error(CMDx::ValidationError, "length must be within 3 and 8")
        end
      end
    end

    context "with :min option only" do
      let(:options) { { min: 5 } }

      context "when value length meets minimum" do
        it "does not raise error for valid lengths" do
          expect { validator.call("12345", options) }.not_to raise_error
          expect { validator.call("123456789", options) }.not_to raise_error
        end
      end

      context "when value length is below minimum" do
        it "raises ValidationError" do
          expect { validator.call("1234", options) }
            .to raise_error(CMDx::ValidationError, "length must be at least 5")
        end
      end

      context "with custom :min_message" do
        let(:options) { { min: 3, min_message: "too short, needs %<min>s+ chars" } }

        it "uses custom message with interpolation" do
          expect { validator.call("ab", options) }
            .to raise_error(CMDx::ValidationError, "too short, needs 3+ chars")
        end
      end
    end

    context "with :max option only" do
      let(:options) { { max: 6 } }

      context "when value length is within maximum" do
        it "does not raise error for valid lengths" do
          expect { validator.call("abc", options) }.not_to raise_error
          expect { validator.call("123456", options) }.not_to raise_error
        end
      end

      context "when value length exceeds maximum" do
        it "raises ValidationError" do
          expect { validator.call("1234567", options) }
            .to raise_error(CMDx::ValidationError, "length must be at most 6")
        end
      end

      context "with custom :max_message" do
        let(:options) { { max: 4, max_message: "too long, max %<max>s chars" } }

        it "uses custom message with interpolation" do
          expect { validator.call("12345", options) }
            .to raise_error(CMDx::ValidationError, "too long, max 4 chars")
        end
      end
    end

    context "with :is option" do
      let(:options) { { is: 5 } }

      context "when value length matches exactly" do
        it "does not raise error for exact length" do
          expect { validator.call("12345", options) }.not_to raise_error
          expect { validator.call("hello", options) }.not_to raise_error
        end
      end

      context "when value length does not match" do
        it "raises ValidationError for shorter values" do
          expect { validator.call("1234", options) }
            .to raise_error(CMDx::ValidationError, "length must be 5")
        end

        it "raises ValidationError for longer values" do
          expect { validator.call("123456", options) }
            .to raise_error(CMDx::ValidationError, "length must be 5")
        end
      end

      context "with custom :is_message" do
        let(:options) { { is: 3, is_message: "must be exactly %<is>s characters" } }

        it "uses custom message with interpolation" do
          expect { validator.call("ab", options) }
            .to raise_error(CMDx::ValidationError, "must be exactly 3 characters")
        end
      end
    end

    context "with :is_not option" do
      let(:options) { { is_not: 4 } }

      context "when value length is not the forbidden length" do
        it "does not raise error for different lengths" do
          expect { validator.call("abc", options) }.not_to raise_error
          expect { validator.call("12345", options) }.not_to raise_error
        end
      end

      context "when value length matches forbidden length" do
        it "raises ValidationError" do
          expect { validator.call("1234", options) }
            .to raise_error(CMDx::ValidationError, "length must not be 4")
        end
      end

      context "with custom :is_not_message" do
        let(:options) { { is_not: 2, is_not_message: "cannot be %<is_not>s chars long" } }

        it "uses custom message with interpolation" do
          expect { validator.call("ab", options) }
            .to raise_error(CMDx::ValidationError, "cannot be 2 chars long")
        end
      end
    end

    context "with custom message priority" do
      context "when multiple message options are provided for :within" do
        let(:options) do
          {
            within: (2..5),
            message: "generic message",
            within_message: "specific within message"
          }
        end

        it "prioritizes specific message over generic" do
          expect { validator.call("a", options) }
            .to raise_error(CMDx::ValidationError, "specific within message")
        end
      end

      context "when multiple message options are provided for :min" do
        let(:options) do
          {
            min: 3,
            message: "generic message",
            min_message: "specific min message"
          }
        end

        it "prioritizes specific message over generic" do
          expect { validator.call("ab", options) }
            .to raise_error(CMDx::ValidationError, "specific min message")
        end
      end
    end

    context "with edge cases" do
      context "when value is empty string" do
        it "validates length correctly" do
          expect { validator.call("", { min: 1 }) }
            .to raise_error(CMDx::ValidationError, "length must be at least 1")

          expect { validator.call("", { is: 0 }) }.not_to raise_error

          expect { validator.call("", { max: 5 }) }.not_to raise_error
        end
      end

      context "when value is array" do
        it "validates array length" do
          expect { validator.call([1, 2, 3], { min: 2 }) }.not_to raise_error
          expect { validator.call([1], { min: 2 }) }
            .to raise_error(CMDx::ValidationError, "length must be at least 2")
        end
      end

      context "when value is hash" do
        it "validates hash length" do
          expect { validator.call({ a: 1, b: 2 }, { max: 3 }) }.not_to raise_error
          expect { validator.call({ a: 1, b: 2, c: 3, d: 4 }, { max: 3 }) }
            .to raise_error(CMDx::ValidationError, "length must be at most 3")
        end
      end

      context "when range has equal bounds" do
        let(:options) { { within: (5..5) } }

        it "validates single-value range correctly" do
          expect { validator.call("12345", options) }.not_to raise_error
          expect { validator.call("1234", options) }
            .to raise_error(CMDx::ValidationError, "length must be within 5 and 5")
        end
      end
    end

    context "with invalid options" do
      it "raises ArgumentError for unknown options" do
        expect { validator.call("test", { unknown: true }) }
          .to raise_error(ArgumentError, "unknown length validator options given")
      end

      it "raises ArgumentError for empty options" do
        expect { validator.call("test", {}) }
          .to raise_error(ArgumentError, "unknown length validator options given")
      end
    end

    context "with internationalization" do
      it "calls Locale.t for default within message" do
        expect(CMDx::Locale).to receive(:t).with(
          "cmdx.validators.length.within",
          min: 3,
          max: 5
        ).and_return("localized within message")

        expect { validator.call("a", { within: (3..5) }) }
          .to raise_error(CMDx::ValidationError, "localized within message")
      end

      it "calls Locale.t for default not_within message" do
        expect(CMDx::Locale).to receive(:t).with(
          "cmdx.validators.length.not_within",
          min: 3,
          max: 5
        ).and_return("localized not_within message")

        expect { validator.call("test", { not_within: (3..5) }) }
          .to raise_error(CMDx::ValidationError, "localized not_within message")
      end

      it "calls Locale.t for default min message" do
        expect(CMDx::Locale).to receive(:t).with(
          "cmdx.validators.length.min",
          min: 3
        ).and_return("localized min message")

        expect { validator.call("ab", { min: 3 }) }
          .to raise_error(CMDx::ValidationError, "localized min message")
      end

      it "calls Locale.t for default max message" do
        expect(CMDx::Locale).to receive(:t).with(
          "cmdx.validators.length.max",
          max: 3
        ).and_return("localized max message")

        expect { validator.call("toolong", { max: 3 }) }
          .to raise_error(CMDx::ValidationError, "localized max message")
      end

      it "calls Locale.t for default is message" do
        expect(CMDx::Locale).to receive(:t).with(
          "cmdx.validators.length.is",
          is: 5
        ).and_return("localized is message")

        expect { validator.call("ab", { is: 5 }) }
          .to raise_error(CMDx::ValidationError, "localized is message")
      end

      it "calls Locale.t for default is_not message" do
        expect(CMDx::Locale).to receive(:t).with(
          "cmdx.validators.length.is_not",
          is_not: 4
        ).and_return("localized is_not message")

        expect { validator.call("test", { is_not: 4 }) }
          .to raise_error(CMDx::ValidationError, "localized is_not message")
      end

      context "when custom message is provided without interpolation" do
        it "does not call string interpolation for custom message" do
          custom_message = "fixed custom message"

          expect { validator.call("a", { min: 3, min_message: custom_message }) }
            .to raise_error(CMDx::ValidationError, custom_message)
        end
      end
    end
  end
end
