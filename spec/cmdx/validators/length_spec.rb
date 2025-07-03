# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Length do
  describe "#call" do
    context "with within range validation" do
      it "passes when string length is within range" do
        expect { described_class.call("hello", length: { within: 3..10 }) }.not_to raise_error
      end

      it "passes when array length is within range" do
        expect { described_class.call([1, 2, 3], length: { within: 2..5 }) }.not_to raise_error
      end

      it "passes when length is at range boundaries" do
        expect { described_class.call("abc", length: { within: 3..10 }) }.not_to raise_error
        expect { described_class.call("abcdefghij", length: { within: 3..10 }) }.not_to raise_error
      end

      it "raises ValidationError when length is below range" do
        expect do
          described_class.call("hi", length: { within: 3..10 })
        end.to raise_error(CMDx::ValidationError, "length must be within 3 and 10")
      end

      it "raises ValidationError when length is above range" do
        expect do
          described_class.call("this is too long", length: { within: 3..10 })
        end.to raise_error(CMDx::ValidationError, "length must be within 3 and 10")
      end
    end

    context "with minimum length validation" do
      it "passes when length meets minimum" do
        expect { described_class.call("password", length: { min: 8 }) }.not_to raise_error
      end

      it "passes when length exceeds minimum" do
        expect { described_class.call("long password", length: { min: 8 }) }.not_to raise_error
      end

      it "passes when length equals minimum" do
        expect { described_class.call("exactly8", length: { min: 8 }) }.not_to raise_error
      end

      it "raises ValidationError when length is below minimum" do
        expect do
          described_class.call("short", length: { min: 8 })
        end.to raise_error(CMDx::ValidationError, "length must be at least 8")
      end
    end

    context "with maximum length validation" do
      it "passes when length is under maximum" do
        expect { described_class.call("short", length: { max: 10 }) }.not_to raise_error
      end

      it "passes when length equals maximum" do
        expect { described_class.call("exactly10!", length: { max: 10 }) }.not_to raise_error
      end

      it "raises ValidationError when length exceeds maximum" do
        expect do
          described_class.call("this is too long", length: { max: 10 })
        end.to raise_error(CMDx::ValidationError, "length must be at most 10")
      end
    end

    context "with combined min and max validation" do
      it "passes when length is between min and max" do
        expect { described_class.call("username", length: { min: 3, max: 20 }) }.not_to raise_error
      end

      it "passes when length equals boundaries" do
        expect { described_class.call("abc", length: { min: 3, max: 20 }) }.not_to raise_error
        expect { described_class.call("a" * 20, length: { min: 3, max: 20 }) }.not_to raise_error
      end

      it "raises ValidationError when length is below minimum" do
        expect do
          described_class.call("ab", length: { min: 3, max: 20 })
        end.to raise_error(CMDx::ValidationError, "length must be within 3 and 20")
      end

      it "raises ValidationError when length is above maximum" do
        expect do
          described_class.call("a" * 25, length: { min: 3, max: 20 })
        end.to raise_error(CMDx::ValidationError, "length must be within 3 and 20")
      end
    end

    context "with exact length validation" do
      it "passes when length matches exactly" do
        expect { described_class.call("US", length: { is: 2 }) }.not_to raise_error
      end

      it "passes when array length matches exactly" do
        expect { described_class.call([1, 2, 3], length: { is: 3 }) }.not_to raise_error
      end

      it "raises ValidationError when length does not match" do
        expect do
          described_class.call("USA", length: { is: 2 })
        end.to raise_error(CMDx::ValidationError, "length must be 2")
      end

      it "raises ValidationError when length is shorter" do
        expect do
          described_class.call("U", length: { is: 2 })
        end.to raise_error(CMDx::ValidationError, "length must be 2")
      end
    end

    context "with custom error messages" do
      it "uses custom min_message" do
        expect do
          described_class.call("short", length: {
                                 min: 8,
                                 min_message: "must be at least %{min} characters for security"
                               })
        end.to raise_error(CMDx::ValidationError, "must be at least 8 characters for security")
      end

      it "uses custom max_message" do
        expect do
          described_class.call("this is too long", length: {
                                 max: 10,
                                 max_message: "cannot exceed %{max} characters"
                               })
        end.to raise_error(CMDx::ValidationError, "cannot exceed 10 characters")
      end

      it "uses custom is_message" do
        expect do
          described_class.call("USA", length: {
                                 is: 2,
                                 is_message: "must be exactly %{is} characters"
                               })
        end.to raise_error(CMDx::ValidationError, "must be exactly 2 characters")
      end

      it "uses general message override" do
        expect do
          described_class.call("fail", length: {
                                 min: 10,
                                 message: "general length error"
                               })
        end.to raise_error(CMDx::ValidationError, "general length error")
      end

      it "uses I18n translation when available" do
        allow(I18n).to receive(:t).with("cmdx.validators.length.min", min: 5, default: "length must be at least 5").and_return("translated min error")

        expect do
          described_class.call("hi", length: { min: 5 })
        end.to raise_error(CMDx::ValidationError, "translated min error")
      end
    end

    context "with different object types" do
      it "validates string length" do
        expect { described_class.call("hello", length: { min: 3 }) }.not_to raise_error
      end

      it "validates array length" do
        expect { described_class.call([1, 2, 3, 4], length: { max: 5 }) }.not_to raise_error
      end

      it "validates hash length" do
        expect { described_class.call({ a: 1, b: 2 }, length: { is: 2 }) }.not_to raise_error
      end

      it "validates set length" do
        expect { described_class.call(Set.new([1, 2, 3]), length: { within: 2..5 }) }.not_to raise_error
      end

      it "validates custom object with length method" do
        custom_object = double("CustomObject", length: 7)
        expect { described_class.call(custom_object, length: { min: 5 }) }.not_to raise_error
      end
    end

    context "with edge cases" do
      it "handles empty string" do
        expect { described_class.call("", length: { min: 0 }) }.not_to raise_error
      end

      it "handles empty array" do
        expect { described_class.call([], length: { is: 0 }) }.not_to raise_error
      end

      it "handles unicode strings" do
        expect { described_class.call("héllo", length: { is: 5 }) }.not_to raise_error
      end

      it "handles very long strings" do
        long_string = "a" * 1000
        expect { described_class.call(long_string, length: { min: 500 }) }.not_to raise_error
      end

      it "handles exclusive ranges" do
        expect { described_class.call("test", length: { within: 1...10 }) }.not_to raise_error
      end

      it "raises ValidationError for exclusive range boundary" do
        expect do
          described_class.call("a" * 10, length: { within: 1...10 })
        end.to raise_error(CMDx::ValidationError, "length must be within 1 and 10")
      end
    end

    context "with invalid options" do
      it "raises ArgumentError when no valid options provided" do
        expect do
          described_class.call("test", length: {})
        end.to raise_error(ArgumentError, "no known length validator options given")
      end

      it "raises ArgumentError when only invalid options provided" do
        expect do
          described_class.call("test", length: { invalid: 5 })
        end.to raise_error(ArgumentError, "no known length validator options given")
      end
    end
  end
end
