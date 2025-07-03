# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Format do
  describe "#call" do
    context "with positive pattern matching" do
      it "passes when value matches with pattern" do
        expect { described_class.call("test@example.com", format: { with: /@/ }) }.not_to raise_error
      end

      it "passes when value matches complex pattern" do
        expect do
          described_class.call("StrongPass123", format: { with: /\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}\z/ })
        end.not_to raise_error
      end

      it "passes when value matches case insensitive pattern" do
        expect { described_class.call("HELLO", format: { with: /hello/i }) }.not_to raise_error
      end

      it "raises ValidationError when value does not match with pattern" do
        expect do
          described_class.call("invalid-email", format: { with: /@/ })
        end.to raise_error(CMDx::ValidationError, "is an invalid format")
      end

      it "raises ValidationError when value does not match complex pattern" do
        expect do
          described_class.call("weak", format: { with: /\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}\z/ })
        end.to raise_error(CMDx::ValidationError, "is an invalid format")
      end
    end

    context "with negative pattern matching" do
      it "passes when value does not match without pattern" do
        expect { described_class.call("username", format: { without: /admin/ }) }.not_to raise_error
      end

      it "passes when value does not match complex without pattern" do
        expect { described_class.call("content", format: { without: /spam|viagra/i }) }.not_to raise_error
      end

      it "raises ValidationError when value matches without pattern" do
        expect do
          described_class.call("admin", format: { without: /admin/ })
        end.to raise_error(CMDx::ValidationError, "is an invalid format")
      end

      it "raises ValidationError when value matches case insensitive without pattern" do
        expect do
          described_class.call("SPAM content", format: { without: /spam/i })
        end.to raise_error(CMDx::ValidationError, "is an invalid format")
      end
    end

    context "with combined patterns" do
      it "passes when value matches with and does not match without" do
        expect do
          described_class.call("StrongPass123", format: {
                                 with: /\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}\z/,
                                 without: /password/i
                               })
        end.not_to raise_error
      end

      it "passes when both conditions are satisfied" do
        expect do
          described_class.call("user@company.com", format: {
                                 with: /@/,
                                 without: /test/
                               })
        end.not_to raise_error
      end

      it "raises ValidationError when with pattern fails" do
        expect do
          described_class.call("invalid-email", format: {
                                 with: /@/,
                                 without: /spam/
                               })
        end.to raise_error(CMDx::ValidationError, "is an invalid format")
      end

      it "raises ValidationError when without pattern fails" do
        expect do
          described_class.call("admin@example.com", format: {
                                 with: /@/,
                                 without: /admin/
                               })
        end.to raise_error(CMDx::ValidationError, "is an invalid format")
      end

      it "raises ValidationError when both patterns fail" do
        expect do
          described_class.call("admin-invalid", format: {
                                 with: /@/,
                                 without: /admin/
                               })
        end.to raise_error(CMDx::ValidationError, "is an invalid format")
      end
    end

    context "with custom error messages" do
      it "uses custom message when with pattern fails" do
        expect do
          described_class.call("invalid", format: {
                                 with: /@/,
                                 message: "must be a valid email"
                               })
        end.to raise_error(CMDx::ValidationError, "must be a valid email")
      end

      it "uses custom message when without pattern fails" do
        expect do
          described_class.call("admin", format: {
                                 without: /admin/,
                                 message: "cannot contain admin"
                               })
        end.to raise_error(CMDx::ValidationError, "cannot contain admin")
      end

      it "uses custom message when combined patterns fail" do
        expect do
          described_class.call("weak", format: {
                                 with: /\A.{8,}\z/,
                                 without: /weak/,
                                 message: "must be strong password"
                               })
        end.to raise_error(CMDx::ValidationError, "must be strong password")
      end

      it "uses I18n translation when available" do
        allow(I18n).to receive(:t).with("cmdx.validators.format", default: "is an invalid format").and_return("translated error")

        expect do
          described_class.call("invalid", format: { with: /@/ })
        end.to raise_error(CMDx::ValidationError, "translated error")
      end
    end

    context "with different regex patterns" do
      it "validates email pattern" do
        email_pattern = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

        expect { described_class.call("user@example.com", format: { with: email_pattern }) }.not_to raise_error
      end

      it "validates phone pattern" do
        phone_pattern = /\A\d{3}-\d{3}-\d{4}\z/

        expect { described_class.call("123-456-7890", format: { with: phone_pattern }) }.not_to raise_error
      end

      it "validates alphanumeric pattern" do
        alphanumeric_pattern = /\A[a-zA-Z0-9]+\z/

        expect { described_class.call("abc123", format: { with: alphanumeric_pattern }) }.not_to raise_error
      end

      it "validates URL pattern" do
        url_pattern = %r{\Ahttps?://}

        expect { described_class.call("https://example.com", format: { with: url_pattern }) }.not_to raise_error
      end
    end

    context "with edge cases" do
      it "handles empty string with pattern" do
        expect do
          described_class.call("", format: { with: /\A.+\z/ })
        end.to raise_error(CMDx::ValidationError, "is an invalid format")
      end

      it "passes empty string with matching pattern" do
        expect { described_class.call("", format: { with: /\A.*\z/ }) }.not_to raise_error
      end

      it "handles unicode characters" do
        expect { described_class.call("héllo", format: { with: /\A[a-záéíóú]+\z/i }) }.not_to raise_error
      end

      it "handles multiline strings" do
        expect do
          described_class.call("line1\nline2", format: { with: /line1.*line2/m })
        end.not_to raise_error
      end

      it "handles special regex characters in string" do
        expect { described_class.call("test.string", format: { with: /test\.string/ }) }.not_to raise_error
      end
    end

    context "with invalid format options" do
      it "raises ValidationError when no valid pattern provided" do
        expect do
          described_class.call("test", format: {})
        end.to raise_error(CMDx::ValidationError, "is an invalid format")
      end

      it "raises ValidationError when only invalid options provided" do
        expect do
          described_class.call("test", format: { invalid: /pattern/ })
        end.to raise_error(CMDx::ValidationError, "is an invalid format")
      end
    end
  end
end
