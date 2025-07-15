# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Format do
  subject(:validator) { described_class.new }

  describe ".call" do
    it "creates instance and calls #call method" do
      expect(described_class).to receive(:new).and_return(validator)
      expect(validator).to receive(:call).with("value", { with: /\A[a-z]+\z/ })

      described_class.call("value",  { with: /\A[a-z]+\z/ })
    end
  end

  describe "#call" do
    context "with positive pattern (with)" do
      it "allows values matching the pattern" do
        expect { validator.call("abc", { with: /\A[a-z]+\z/ }) }.not_to raise_error
        expect { validator.call("user123", { with: /\A[a-z]+\d+\z/ }) }.not_to raise_error
      end

      it "raises ValidationError when value doesn't match pattern" do
        expect { validator.call("123", { with: /\A[a-z]+\z/ }) }
          .to raise_error(CMDx::ValidationError, "is an invalid format")
      end

      it "raises ValidationError when value is empty and pattern requires content" do
        expect { validator.call("", { with: /\A[a-z]+\z/ }) }
          .to raise_error(CMDx::ValidationError, "is an invalid format")
      end

      it "uses custom message when provided" do
        options = { with: /\A[a-z]+\z/, message: "Must contain only lowercase letters" }

        expect { validator.call("123", options) }
          .to raise_error(CMDx::ValidationError, "Must contain only lowercase letters")
      end

      it "works with complex patterns" do
        email_pattern = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

        expect { validator.call("user@example.com", { with: email_pattern }) }.not_to raise_error
        expect { validator.call("invalid-email", { with: email_pattern }) }
          .to raise_error(CMDx::ValidationError, "is an invalid format")
      end
    end

    context "with negative pattern (without)" do
      it "allows values not matching the pattern" do
        expect { validator.call("user",  { without: /admin|root/ }) }.not_to raise_error
        expect { validator.call("guest123", { without: /admin|root/ }) }.not_to raise_error
      end

      it "raises ValidationError when value matches forbidden pattern" do
        expect { validator.call("admin", { without: /admin|root/ }) }
          .to raise_error(CMDx::ValidationError, "is an invalid format")
        expect { validator.call("root_user", { without: /admin|root/ }) }
          .to raise_error(CMDx::ValidationError, "is an invalid format")
      end

      it "allows empty values when pattern doesn't match" do
        expect { validator.call("", { without: /admin|root/ }) }.not_to raise_error
      end

      it "uses custom message when provided" do
        options = { without: /admin|root/, message: "Reserved usernames not allowed" }

        expect { validator.call("admin", options) }
          .to raise_error(CMDx::ValidationError, "Reserved usernames not allowed")
      end
    end

    context "with combined patterns (with and without)" do
      it "allows values matching 'with' pattern and not matching 'without' pattern" do
        options = { with: /\A[a-z]+\d+\z/, without: /admin|root/ }

        expect { validator.call("user123", options) }.not_to raise_error
        expect { validator.call("guest456", options) }.not_to raise_error
      end

      it "raises ValidationError when value doesn't match 'with' pattern" do
        options = { with: /\A[a-z]+\d+\z/, without: /admin|root/ }

        expect { validator.call("123abc", options) }
          .to raise_error(CMDx::ValidationError, "is an invalid format")
      end

      it "raises ValidationError when value matches 'without' pattern" do
        options = { with: /\A[a-z]+\d+\z/, without: /admin|root/ }

        expect { validator.call("admin123", options) }
          .to raise_error(CMDx::ValidationError, "is an invalid format")
      end

      it "raises ValidationError when value fails both patterns" do
        options = { with: /\A[a-z]+\d+\z/, without: /admin|root/ }

        expect { validator.call("ADMIN", options) }
          .to raise_error(CMDx::ValidationError, "is an invalid format")
      end

      it "uses custom message when provided" do
        options = {
          with: /\A[a-z]+\d+\z/,
          without: /admin|root/,
          message: "Invalid username format"
        }

        expect { validator.call("admin123", options) }
          .to raise_error(CMDx::ValidationError, "Invalid username format")
      end
    end

    context "with edge cases" do
      it "raises NoMethodError for nil values" do
        expect { validator.call(nil,  { with: /\A[a-z]+\z/ }) }
          .to raise_error(NoMethodError, /undefined method 'match\?' for nil/)
      end

      it "raises NoMethodError for non-string values" do
        expect { validator.call(123,  { with: /\A\d+\z/ }) }
          .to raise_error(NoMethodError, /undefined method 'match\?' for an instance of Integer/)
      end

      it "handles symbols correctly" do
        expect { validator.call(:admin,  { with: /\A[a-z]+\z/ }) }.not_to raise_error
        expect { validator.call(:admin,  { without: /admin/ }) }
          .to raise_error(CMDx::ValidationError, "is an invalid format")
      end

      it "returns early for valid cases" do
        expect(validator.call("valid", { with: /\A[a-z]+\z/ })).to be_nil
      end
    end

    context "with missing or invalid options" do
      it "raises ValidationError when no format options provided" do
        expect { validator.call("any_value", {}) }
          .to raise_error(CMDx::ValidationError, "is an invalid format")
      end

      it "raises TypeError when format patterns are nil" do
        expect { validator.call("any_value", { with: nil }) }
          .to raise_error(TypeError, /wrong argument type nil \(expected Regexp\)/)
      end
    end
  end

  describe "integration with tasks" do
    let(:task_class) do
      create_simple_task(name: "UserValidationTask") do
        required :username, type: :string, format: { with: /\A[a-z]+\d+\z/, without: /admin|root/ }
        optional :email, type: :string, default: "user@example.com",
                         format: { with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i }

        def call
          context.validated_user = { username: username, email: email }
        end
      end
    end

    it "validates successfully with valid formats" do
      result = task_class.call(username: "user123", email: "user@example.com")

      expect(result).to be_success
      expect(result.context.validated_user).to eq({ username: "user123", email: "user@example.com" })
    end

    it "fails when username doesn't match required format" do
      result = task_class.call(username: "123abc")

      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("username is an invalid format")
      expect(result.metadata[:messages]).to eq({ username: ["is an invalid format"] })
    end

    it "fails when username matches forbidden pattern" do
      result = task_class.call(username: "admin123")

      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("username is an invalid format")
      expect(result.metadata[:messages]).to eq({ username: ["is an invalid format"] })
    end

    it "fails when email has invalid format" do
      result = task_class.call(username: "user123", email: "invalid-email")

      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("email is an invalid format")
      expect(result.metadata[:messages]).to eq({ email: ["is an invalid format"] })
    end

    it "validates with custom messages" do
      custom_task = create_simple_task(name: "CustomValidationTask") do
        required :code, type: :string, format: {
          with: /\A[A-Z]{2}\d{4}\z/,
          message: "Code must be 2 uppercase letters followed by 4 digits"
        }

        def call
          context.validated_code = code
        end
      end

      result = custom_task.call(code: "invalid")
      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("code Code must be 2 uppercase letters followed by 4 digits")
      expect(result.metadata[:messages]).to eq({ code: ["Code must be 2 uppercase letters followed by 4 digits"] })
    end

    it "works with multiple format validations" do
      multi_task = create_simple_task(name: "MultiFormatTask") do
        required :username, type: :string, format: { with: /\A[a-z]+\d+\z/ }
        required :password, type: :string, format: { without: /password|123456/, message: "Weak password" }

        def call
          context.validated_credentials = { username: username, password: password }
        end
      end

      result = multi_task.call(username: "user123", password: "strong_pass")
      expect(result).to be_success

      result = multi_task.call(username: "invalid", password: "strong_pass")
      expect(result).to be_failed

      result = multi_task.call(username: "user123", password: "password")
      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("password Weak password")
    end

    it "validates with only positive pattern" do
      positive_task = create_simple_task(name: "PositiveFormatTask") do
        required :slug, type: :string, format: { with: /\A[a-z0-9\-]+\z/ }

        def call
          context.validated_slug = slug
        end
      end

      expect(positive_task.call(slug: "valid-slug-123")).to be_success
      expect(positive_task.call(slug: "Invalid_Slug")).to be_failed
    end

    it "validates with only negative pattern" do
      negative_task = create_simple_task(name: "NegativeFormatTask") do
        required :content, type: :string, format: { without: /<script|javascript:/ }

        def call
          context.validated_content = content
        end
      end

      expect(negative_task.call(content: "Safe content")).to be_success
      expect(negative_task.call(content: "Unsafe <script>")).to be_failed
    end
  end
end
