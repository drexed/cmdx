# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Presence do
  describe "#call" do
    context "with string values" do
      it "passes when string contains non-whitespace characters" do
        expect { described_class.call("hello", presence: true) }.not_to raise_error
      end

      it "passes when string contains mixed whitespace and characters" do
        expect { described_class.call("  hello  ", presence: true) }.not_to raise_error
      end

      it "passes when string contains only one character" do
        expect { described_class.call("a", presence: true) }.not_to raise_error
      end

      it "raises ValidationError when string is empty" do
        expect do
          described_class.call("", presence: true)
        end.to raise_error(CMDx::ValidationError, "cannot be empty")
      end

      it "raises ValidationError when string contains only spaces" do
        expect do
          described_class.call("   ", presence: true)
        end.to raise_error(CMDx::ValidationError, "cannot be empty")
      end

      it "raises ValidationError when string contains only tabs and newlines" do
        expect do
          described_class.call("\n\t", presence: true)
        end.to raise_error(CMDx::ValidationError, "cannot be empty")
      end

      it "raises ValidationError when string contains only various whitespace" do
        expect do
          described_class.call(" \t\n\r\f\v", presence: true)
        end.to raise_error(CMDx::ValidationError, "cannot be empty")
      end
    end

    context "with collection values" do
      it "passes when array is not empty" do
        expect { described_class.call([1, 2, 3], presence: true) }.not_to raise_error
      end

      it "passes when hash is not empty" do
        expect { described_class.call({ key: "value" }, presence: true) }.not_to raise_error
      end

      it "passes when set is not empty" do
        expect { described_class.call(Set.new([1, 2]), presence: true) }.not_to raise_error
      end

      it "raises ValidationError when array is empty" do
        expect do
          described_class.call([], presence: true)
        end.to raise_error(CMDx::ValidationError, "cannot be empty")
      end

      it "raises ValidationError when hash is empty" do
        expect do
          described_class.call({}, presence: true)
        end.to raise_error(CMDx::ValidationError, "cannot be empty")
      end

      it "raises ValidationError when set is empty" do
        expect do
          described_class.call(Set.new, presence: true)
        end.to raise_error(CMDx::ValidationError, "cannot be empty")
      end
    end

    context "with other object values" do
      it "passes when value is integer zero" do
        expect { described_class.call(0, presence: true) }.not_to raise_error
      end

      it "passes when value is false" do
        expect { described_class.call(false, presence: true) }.not_to raise_error
      end

      it "passes when value is positive integer" do
        expect { described_class.call(42, presence: true) }.not_to raise_error
      end

      it "passes when value is negative integer" do
        expect { described_class.call(-5, presence: true) }.not_to raise_error
      end

      it "passes when value is float" do
        expect { described_class.call(3.14, presence: true) }.not_to raise_error
      end

      it "passes when value is object instance" do
        expect { described_class.call(Object.new, presence: true) }.not_to raise_error
      end

      it "raises ValidationError when value is nil" do
        expect do
          described_class.call(nil, presence: true)
        end.to raise_error(CMDx::ValidationError, "cannot be empty")
      end
    end

    context "with custom error messages" do
      it "uses custom message from hash options" do
        expect do
          described_class.call("", presence: { message: "is required" })
        end.to raise_error(CMDx::ValidationError, "is required")
      end

      it "uses custom message for nil values" do
        expect do
          described_class.call(nil, presence: { message: "must be provided" })
        end.to raise_error(CMDx::ValidationError, "must be provided")
      end

      it "uses custom message for empty collections" do
        expect do
          described_class.call([], presence: { message: "cannot be blank" })
        end.to raise_error(CMDx::ValidationError, "cannot be blank")
      end

      it "uses I18n translation when available" do
        allow(I18n).to receive(:t).with("cmdx.validators.presence", default: "cannot be empty").and_return("translated error")

        expect do
          described_class.call("", presence: true)
        end.to raise_error(CMDx::ValidationError, "translated error")
      end
    end

    context "with boolean presence option" do
      it "validates when presence is true" do
        expect do
          described_class.call("", presence: true)
        end.to raise_error(CMDx::ValidationError)
      end

      it "passes validation when presence is true and value is present" do
        expect { described_class.call("value", presence: true) }.not_to raise_error
      end
    end

    context "with hash presence option" do
      it "validates when presence is hash without message" do
        expect do
          described_class.call("", presence: {})
        end.to raise_error(CMDx::ValidationError, "cannot be empty")
      end

      it "validates when presence is hash with message" do
        expect do
          described_class.call("", presence: { message: "custom" })
        end.to raise_error(CMDx::ValidationError, "custom")
      end
    end

    context "with edge cases" do
      it "handles string with unicode whitespace" do
        expect { described_class.call("\u00A0\u2000\u2001", presence: true) }.not_to raise_error
      end

      it "passes with string containing unicode characters" do
        expect { described_class.call("héllo", presence: true) }.not_to raise_error
      end

      it "handles custom objects responding to empty?" do
        custom_object = double("CustomObject", empty?: false)

        expect { described_class.call(custom_object, presence: true) }.not_to raise_error
      end

      it "handles empty custom objects responding to empty?" do
        custom_object = double("CustomObject", empty?: true)

        expect do
          described_class.call(custom_object, presence: true)
        end.to raise_error(CMDx::ValidationError, "cannot be empty")
      end
    end
  end
end
