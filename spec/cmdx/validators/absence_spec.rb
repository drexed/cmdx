# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Absence, type: :unit do
  subject(:validator) { described_class }

  describe ".call" do
    context "when value is absent" do
      context "with string values" do
        it "does not raise error for empty strings" do
          expect { validator.call("") }.not_to raise_error
        end

        it "does not raise error for whitespace-only strings" do
          expect { validator.call("   ") }.not_to raise_error
          expect { validator.call("\t\n\r ") }.not_to raise_error
        end
      end

      context "with objects responding to empty?" do
        it "does not raise error for empty arrays" do
          expect { validator.call([]) }.not_to raise_error
        end

        it "does not raise error for empty hashes" do
          expect { validator.call({}) }.not_to raise_error
        end

        it "does not raise error for empty string-like objects" do
          empty_obj = Object.new
          def empty_obj.empty? = true
          expect { validator.call(empty_obj) }.not_to raise_error
        end
      end

      context "with nil values" do
        it "does not raise error for nil" do
          expect { validator.call(nil) }.not_to raise_error
        end
      end
    end

    context "when value is present" do
      context "with string values" do
        it "raises ValidationError for non-whitespace strings" do
          expect { validator.call("hello") }
            .to raise_error(CMDx::ValidationError, "must be empty")
          expect { validator.call("a") }
            .to raise_error(CMDx::ValidationError, "must be empty")
          expect { validator.call("123") }
            .to raise_error(CMDx::ValidationError, "must be empty")
        end

        it "raises ValidationError for strings with mixed whitespace and content" do
          expect { validator.call(" hello ") }
            .to raise_error(CMDx::ValidationError, "must be empty")
          expect { validator.call("\thello\n") }
            .to raise_error(CMDx::ValidationError, "must be empty")
          expect { validator.call("  a  ") }
            .to raise_error(CMDx::ValidationError, "must be empty")
        end
      end

      context "with objects responding to empty?" do
        it "raises ValidationError for non-empty arrays" do
          expect { validator.call([1, 2, 3]) }
            .to raise_error(CMDx::ValidationError, "must be empty")
          expect { validator.call(["a"]) }
            .to raise_error(CMDx::ValidationError, "must be empty")
        end

        it "raises ValidationError for non-empty hashes" do
          expect { validator.call({ a: 1 }) }
            .to raise_error(CMDx::ValidationError, "must be empty")
          expect { validator.call({ "key" => "value" }) }
            .to raise_error(CMDx::ValidationError, "must be empty")
        end

        it "raises ValidationError for non-empty string-like objects" do
          string_obj = Object.new
          def string_obj.empty? = false
          expect { validator.call(string_obj) }
            .to raise_error(CMDx::ValidationError, "must be empty")
        end
      end

      context "with objects not responding to empty?" do
        it "raises ValidationError for non-nil values" do
          expect { validator.call(42) }
            .to raise_error(CMDx::ValidationError, "must be empty")
          expect { validator.call(true) }
            .to raise_error(CMDx::ValidationError, "must be empty")
          expect { validator.call(false) }
            .to raise_error(CMDx::ValidationError, "must be empty")
          expect { validator.call(0) }
            .to raise_error(CMDx::ValidationError, "must be empty")
        end

        it "raises ValidationError for objects" do
          expect { validator.call(Object.new) }
            .to raise_error(CMDx::ValidationError, "must be empty")
          expect { validator.call(Date.today) }
            .to raise_error(CMDx::ValidationError, "must be empty")
        end
      end
    end

    context "with custom message option" do
      let(:custom_message) { "must be blank" }
      let(:options) { { message: custom_message } }

      it "uses custom message for present strings" do
        expect { validator.call("hello", options) }
          .to raise_error(CMDx::ValidationError, custom_message)
      end

      it "uses custom message for present arrays" do
        expect { validator.call([1], options) }
          .to raise_error(CMDx::ValidationError, custom_message)
      end

      it "uses custom message for present objects" do
        expect { validator.call(true, options) }
          .to raise_error(CMDx::ValidationError, custom_message)
      end

      it "does not raise error for absent values" do
        expect { validator.call(nil, options) }.not_to raise_error
        expect { validator.call("", options) }.not_to raise_error
      end
    end

    context "without options" do
      it "does not raise error when no options provided for absent value" do
        expect { validator.call("") }.not_to raise_error
      end

      it "raises error with default message when no options provided for present value" do
        expect { validator.call("hello") }
          .to raise_error(CMDx::ValidationError, "must be empty")
      end
    end

    context "with non-hash options" do
      it "ignores non-hash options and uses default message" do
        expect { validator.call("hello", "invalid_options") }
          .to raise_error(CMDx::ValidationError, "must be empty")
        expect { validator.call("hello", 123) }
          .to raise_error(CMDx::ValidationError, "must be empty")
      end
    end
  end
end
