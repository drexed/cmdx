# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Presence do
  subject(:validator) { described_class }

  describe ".call" do
    context "when value is present" do
      context "with string values" do
        it "does not raise error for non-whitespace strings" do
          expect { validator.call("hello") }.not_to raise_error
          expect { validator.call("a") }.not_to raise_error
          expect { validator.call("123") }.not_to raise_error
        end

        it "does not raise error for strings with mixed whitespace and content" do
          expect { validator.call(" hello ") }.not_to raise_error
          expect { validator.call("\thello\n") }.not_to raise_error
          expect { validator.call("  a  ") }.not_to raise_error
        end
      end

      context "with objects responding to empty?" do
        it "does not raise error for non-empty arrays" do
          expect { validator.call([1, 2, 3]) }.not_to raise_error
          expect { validator.call(["a"]) }.not_to raise_error
        end

        it "does not raise error for non-empty hashes" do
          expect { validator.call({ a: 1 }) }.not_to raise_error
          expect { validator.call({ "key" => "value" }) }.not_to raise_error
        end

        it "does not raise error for non-empty string-like objects" do
          string_obj = Object.new
          def string_obj.empty? = false
          expect { validator.call(string_obj) }.not_to raise_error
        end
      end

      context "with objects not responding to empty?" do
        it "does not raise error for non-nil values" do
          expect { validator.call(42) }.not_to raise_error
          expect { validator.call(true) }.not_to raise_error
          expect { validator.call(false) }.not_to raise_error
          expect { validator.call(0) }.not_to raise_error
        end

        it "does not raise error for objects" do
          expect { validator.call(Object.new) }.not_to raise_error
          expect { validator.call(Date.today) }.not_to raise_error
        end
      end
    end

    context "when value is not present" do
      context "with string values" do
        it "raises ValidationError for empty strings" do
          expect { validator.call("") }
            .to raise_error(CMDx::ValidationError, "cannot be empty")
        end

        it "raises ValidationError for whitespace-only strings" do
          expect { validator.call("   ") }
            .to raise_error(CMDx::ValidationError, "cannot be empty")
          expect { validator.call("\t\n\r ") }
            .to raise_error(CMDx::ValidationError, "cannot be empty")
        end
      end

      context "with objects responding to empty?" do
        it "raises ValidationError for empty arrays" do
          expect { validator.call([]) }
            .to raise_error(CMDx::ValidationError, "cannot be empty")
        end

        it "raises ValidationError for empty hashes" do
          expect { validator.call({}) }
            .to raise_error(CMDx::ValidationError, "cannot be empty")
        end

        it "raises ValidationError for empty string-like objects" do
          empty_obj = Object.new
          def empty_obj.empty? = true
          expect { validator.call(empty_obj) }
            .to raise_error(CMDx::ValidationError, "cannot be empty")
        end
      end

      context "with nil values" do
        it "raises ValidationError for nil" do
          expect { validator.call(nil) }
            .to raise_error(CMDx::ValidationError, "cannot be empty")
        end
      end
    end

    context "with custom message option" do
      let(:custom_message) { "is required" }
      let(:options) { { message: custom_message } }

      it "uses custom message for empty strings" do
        expect { validator.call("", options) }
          .to raise_error(CMDx::ValidationError, custom_message)
      end

      it "uses custom message for whitespace-only strings" do
        expect { validator.call("   ", options) }
          .to raise_error(CMDx::ValidationError, custom_message)
      end

      it "uses custom message for empty arrays" do
        expect { validator.call([], options) }
          .to raise_error(CMDx::ValidationError, custom_message)
      end

      it "uses custom message for nil values" do
        expect { validator.call(nil, options) }
          .to raise_error(CMDx::ValidationError, custom_message)
      end

      it "does not raise error for present values" do
        expect { validator.call("hello", options) }.not_to raise_error
        expect { validator.call([1], options) }.not_to raise_error
      end
    end

    context "without options" do
      it "does not raise error when no options provided" do
        expect { validator.call("hello") }.not_to raise_error
      end

      it "raises error with default message when no options provided" do
        expect { validator.call("") }
          .to raise_error(CMDx::ValidationError, "cannot be empty")
      end
    end

    context "with non-hash options" do
      it "ignores non-hash options and uses default message" do
        expect { validator.call("", "invalid_options") }
          .to raise_error(CMDx::ValidationError, "cannot be empty")
        expect { validator.call("", 123) }
          .to raise_error(CMDx::ValidationError, "cannot be empty")
      end
    end

    context "with edge cases" do
      it "handles zero correctly (not empty)" do
        expect { validator.call(0) }.not_to raise_error
      end

      it "handles false correctly (not empty)" do
        expect { validator.call(false) }.not_to raise_error
      end

      it "handles objects not responding to empty?" do
        custom_obj = Object.new

        expect { validator.call(custom_obj) }.not_to raise_error
      end
    end
  end
end
