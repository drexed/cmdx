# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Format, type: :unit do
  subject(:validator) { described_class }

  describe ".call" do
    context "with direct Regexp argument" do
      it "validates value against the regex pattern" do
        expect { validator.call("hello", /\A[a-z]+\z/) }.not_to raise_error
        expect { validator.call("123", /\A\d+\z/) }.not_to raise_error
        expect { validator.call("test@example.com", /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i) }.not_to raise_error
      end

      it "raises ValidationError when value doesn't match pattern" do
        expect { validator.call("Hello", /\A[a-z]+\z/) }
          .to raise_error(CMDx::ValidationError, "is an invalid format")
        expect { validator.call("abc", /\A\d+\z/) }
          .to raise_error(CMDx::ValidationError, "is an invalid format")
        expect { validator.call("invalid-email", /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i) }
          .to raise_error(CMDx::ValidationError, "is an invalid format")
      end

      it "handles complex regex patterns" do
        phone_regex = /\A\+?1?[-.\s]?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}\z/
        expect { validator.call("123-456-7890", phone_regex) }.not_to raise_error
        expect { validator.call("(123) 456-7890", phone_regex) }.not_to raise_error
        expect { validator.call("123-45-6789", phone_regex) }
          .to raise_error(CMDx::ValidationError, "is an invalid format")
      end

      it "works with edge cases" do
        expect { validator.call("", /\A.*\z/) }.not_to raise_error
        expect { validator.call("", /\A.+\z/) }
          .to raise_error(CMDx::ValidationError, "is an invalid format")
        expect { validator.call(nil, /\A.+\z/) }
          .to raise_error(CMDx::ValidationError, "is an invalid format")
      end
    end

    context "with :with option" do
      let(:options) { { with: /\A[a-z]+\z/ } }

      context "when value matches pattern" do
        it "does not raise error for matching values" do
          expect { validator.call("hello", options) }.not_to raise_error
          expect { validator.call("world", options) }.not_to raise_error
          expect { validator.call("test", options) }.not_to raise_error
        end
      end

      context "when value does not match pattern" do
        it "raises ValidationError with default message" do
          expect { validator.call("Hello", options) }
            .to raise_error(CMDx::ValidationError, "is an invalid format")
        end

        it "raises ValidationError for various invalid formats" do
          ["Hello", "123", "test_case", ""].each do |invalid_value|
            expect { validator.call(invalid_value, options) }
              .to raise_error(CMDx::ValidationError, "is an invalid format")
          end
        end
      end

      context "with custom message" do
        let(:options) { { with: /\A\d+\z/, message: "must contain only digits" } }

        it "uses custom message when validation fails" do
          expect { validator.call("abc", options) }
            .to raise_error(CMDx::ValidationError, "must contain only digits")
        end
      end

      context "with email pattern" do
        let(:options) { { with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i } }

        it "validates email format correctly" do
          expect { validator.call("user@example.com", options) }.not_to raise_error
          expect { validator.call("test.email+tag@domain.co.uk", options) }.not_to raise_error
        end

        it "rejects invalid email formats" do
          expect { validator.call("invalid-email", options) }
            .to raise_error(CMDx::ValidationError)
          expect { validator.call("@example.com", options) }
            .to raise_error(CMDx::ValidationError)
        end
      end
    end

    context "with :without option" do
      let(:options) { { without: /[^a-zA-Z]/ } }

      context "when value does not match forbidden pattern" do
        it "does not raise error for valid values" do
          expect { validator.call("Hello", options) }.not_to raise_error
          expect { validator.call("World", options) }.not_to raise_error
          expect { validator.call("", options) }.not_to raise_error
        end
      end

      context "when value matches forbidden pattern" do
        it "raises ValidationError with default message" do
          expect { validator.call("hello123", options) }
            .to raise_error(CMDx::ValidationError, "is an invalid format")
        end

        it "raises ValidationError for various invalid formats" do
          ["test_case", "hello!", "123", "hello world"].each do |invalid_value|
            expect { validator.call(invalid_value, options) }
              .to raise_error(CMDx::ValidationError, "is an invalid format")
          end
        end
      end

      context "with custom message" do
        let(:options) { { without: /\d/, message: "cannot contain numbers" } }

        it "uses custom message when validation fails" do
          expect { validator.call("test123", options) }
            .to raise_error(CMDx::ValidationError, "cannot contain numbers")
        end
      end
    end

    context "with both :with and :without options" do
      let(:options) { { with: /\A[a-zA-Z]+\z/, without: /[A-Z]{2,}/ } }

      context "when value matches :with and does not match :without" do
        it "does not raise error for valid values" do
          expect { validator.call("Hello", options) }.not_to raise_error
          expect { validator.call("world", options) }.not_to raise_error
          expect { validator.call("Test", options) }.not_to raise_error
        end
      end

      context "when value does not match :with pattern" do
        it "raises ValidationError" do
          expect { validator.call("hello123", options) }
            .to raise_error(CMDx::ValidationError, "is an invalid format")
          expect { validator.call("test_case", options) }
            .to raise_error(CMDx::ValidationError, "is an invalid format")
        end
      end

      context "when value matches :without pattern" do
        it "raises ValidationError for forbidden patterns" do
          expect { validator.call("HELLO", options) }
            .to raise_error(CMDx::ValidationError, "is an invalid format")
          expect { validator.call("TEST", options) }
            .to raise_error(CMDx::ValidationError, "is an invalid format")
        end
      end

      context "when value fails both conditions" do
        it "raises ValidationError" do
          expect { validator.call("HELLO123", options) }
            .to raise_error(CMDx::ValidationError, "is an invalid format")
        end
      end

      context "with custom message" do
        let(:options) do
          {
            with: /\A[a-z]+\z/,
            without: /test/,
            message: "must be lowercase letters without 'test'"
          }
        end

        it "uses custom message when validation fails" do
          expect { validator.call("testing", options) }
            .to raise_error(CMDx::ValidationError, "must be lowercase letters without 'test'")
        end
      end
    end

    context "without any pattern options" do
      let(:options) { {} }

      it "always raises ValidationError" do
        expect { validator.call("anything", options) }
          .to raise_error(CMDx::ValidationError, "is an invalid format")
        expect { validator.call("", options) }
          .to raise_error(CMDx::ValidationError, "is an invalid format")
      end

      context "with custom message" do
        let(:options) { { message: "no pattern specified" } }

        it "uses custom message" do
          expect { validator.call("test", options) }
            .to raise_error(CMDx::ValidationError, "no pattern specified")
        end
      end
    end

    context "with complex regex patterns" do
      context "when validating phone numbers" do
        let(:options) { { with: /\A\+?1?[-.\s]?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}\z/ } }

        it "validates various phone number formats" do
          valid_numbers = [
            "123-456-7890",
            "(123) 456-7890",
            "123.456.7890",
            "1234567890",
            "+1-123-456-7890"
          ]

          valid_numbers.each do |number|
            expect { validator.call(number, options) }.not_to raise_error
          end
        end

        it "rejects invalid phone number formats" do
          invalid_numbers = %w[
            123-45-6789
            abc-def-ghij
            123-456-78901
          ]

          invalid_numbers.each do |number|
            expect { validator.call(number, options) }
              .to raise_error(CMDx::ValidationError)
          end
        end
      end

      context "when validating hexadecimal colors" do
        let(:options) { { with: /\A#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})\z/ } }

        it "validates hex color codes" do
          expect { validator.call("#FF0000", options) }.not_to raise_error
          expect { validator.call("#fff", options) }.not_to raise_error
          expect { validator.call("#123abc", options) }.not_to raise_error
        end

        it "rejects invalid hex color codes" do
          expect { validator.call("FF0000", options) }
            .to raise_error(CMDx::ValidationError)
          expect { validator.call("#gg0000", options) }
            .to raise_error(CMDx::ValidationError)
        end
      end
    end

    context "with string patterns" do
      let(:options) { { with: "test" } }

      it "treats string patterns as regex" do
        expect { validator.call("testing", options) }.not_to raise_error
        expect { validator.call("retest", options) }.not_to raise_error
      end

      it "raises error when string pattern not found" do
        expect { validator.call("hello", options) }
          .to raise_error(CMDx::ValidationError)
      end
    end

    context "with edge case values" do
      let(:options) { { with: /\A.+\z/ } }

      it "handles empty strings" do
        expect { validator.call("", { with: /\A.*\z/ }) }.not_to raise_error
        expect { validator.call("", options) }
          .to raise_error(CMDx::ValidationError)
      end

      it "handles very long strings" do
        long_string = "a" * 10_000
        expect { validator.call(long_string, options) }.not_to raise_error
      end
    end
  end
end
