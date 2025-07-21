# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Length do
  subject(:validator) { described_class.new }

  describe ".call" do
    it "creates instance and calls #call method" do
      expect(described_class).to receive(:new).and_return(validator)
      expect(validator).to receive(:call).with("value", { min: 3 })

      described_class.call("value", { min: 3 })
    end
  end

  describe "#call" do
    context "with within validation" do
      it "allows values within the specified range" do
        expect { validator.call("hello", { within: 3..10 }) }.not_to raise_error
        expect { validator.call("hi", { within: 1..5 }) }.not_to raise_error
        expect { validator.call("test",  { within: 4..4 }) }.not_to raise_error
      end

      it "allows values within the specified range using in alias" do
        expect { validator.call("hello", { in: 3..10 }) }.not_to raise_error
        expect { validator.call("hi",  { in: 1..5 }) }.not_to raise_error
      end

      it "raises ValidationError when value is outside range" do
        expect { validator.call("hi",  { within: 3..10 }) }
          .to raise_error(CMDx::ValidationError, "length must be within 3 and 10")
      end

      it "raises ValidationError when value is outside range using in alias" do
        expect { validator.call("hello world!",  { in: 3..10 }) }
          .to raise_error(CMDx::ValidationError, "length must be within 3 and 10")
      end

      it "uses custom within_message when provided" do
        options = { within: 3..10, within_message: "Must be between %{min} and %{max} characters" }

        expect { validator.call("hi", options) }
          .to raise_error(CMDx::ValidationError, "Must be between 3 and 10 characters")
      end

      it "uses custom in_message when provided" do
        options = { in: 3..10, in_message: "Length should be %{min}-%{max}" }

        expect { validator.call("hi", options) }
          .to raise_error(CMDx::ValidationError, "Length should be 3-10")
      end

      it "uses custom message when provided" do
        options = { within: 3..10, message: "Invalid length" }

        expect { validator.call("hi", options) }
          .to raise_error(CMDx::ValidationError, "Invalid length")
      end
    end

    context "with not_within validation" do
      it "allows values outside the forbidden range" do
        expect { validator.call("hi",  { not_within: 3..10 }) }.not_to raise_error
        expect { validator.call("hello world!",  { not_within: 3..10 }) }.not_to raise_error
      end

      it "allows values outside the forbidden range using not_in alias" do
        expect { validator.call("hi",  { not_in: 3..10 }) }.not_to raise_error
        expect { validator.call("hello world!",  { not_in: 3..10 }) }.not_to raise_error
      end

      it "raises ValidationError when value is within forbidden range" do
        expect { validator.call("hello", { not_within: 3..10 }) }
          .to raise_error(CMDx::ValidationError, "length must not be within 3 and 10")
      end

      it "raises ValidationError when value is within forbidden range using not_in alias" do
        expect { validator.call("test", { not_in: 3..10 }) }
          .to raise_error(CMDx::ValidationError, "length must not be within 3 and 10")
      end

      it "uses custom not_within_message when provided" do
        options = { not_within: 3..10, not_within_message: "Cannot be %{min} to %{max} chars" }

        expect { validator.call("hello", options) }
          .to raise_error(CMDx::ValidationError, "Cannot be 3 to 10 chars")
      end

      it "uses custom not_in_message when provided" do
        options = { not_in: 3..10, not_in_message: "Forbidden range: %{min}-%{max}" }

        expect { validator.call("test", options) }
          .to raise_error(CMDx::ValidationError, "Forbidden range: 3-10")
      end

      it "uses custom message when provided" do
        options = { not_within: 3..10, message: "Length not allowed" }

        expect { validator.call("hello", options) }
          .to raise_error(CMDx::ValidationError, "Length not allowed")
      end
    end

    context "with min validation" do
      it "allows values meeting minimum length" do
        expect { validator.call("hello", { min: 5 }) }.not_to raise_error
        expect { validator.call("hello world",  { min: 5 }) }.not_to raise_error
      end

      it "raises ValidationError when value is below minimum" do
        expect { validator.call("hi",  { min: 5 }) }
          .to raise_error(CMDx::ValidationError, "length must be at least 5")
      end

      it "uses custom min_message when provided" do
        options = { min: 5, min_message: "Must have at least %{min} characters" }

        expect { validator.call("hi", options) }
          .to raise_error(CMDx::ValidationError, "Must have at least 5 characters")
      end

      it "uses custom message when provided" do
        options = { min: 5, message: "Too short" }

        expect { validator.call("hi", options) }
          .to raise_error(CMDx::ValidationError, "Too short")
      end
    end

    context "with max validation" do
      it "allows values meeting maximum length" do
        expect { validator.call("hello", { max: 10 }) }.not_to raise_error
        expect { validator.call("hi",  { max: 10 }) }.not_to raise_error
      end

      it "raises ValidationError when value exceeds maximum" do
        expect { validator.call("hello world!",  { max: 10 }) }
          .to raise_error(CMDx::ValidationError, "length must be at most 10")
      end

      it "uses custom max_message when provided" do
        options = { max: 10, max_message: "Cannot exceed %{max} characters" }

        expect { validator.call("hello world!", options) }
          .to raise_error(CMDx::ValidationError, "Cannot exceed 10 characters")
      end

      it "uses custom message when provided" do
        options = { max: 10, message: "Too long" }

        expect { validator.call("hello world!", options) }
          .to raise_error(CMDx::ValidationError, "Too long")
      end
    end

    context "with min and max validation" do
      it "allows values within min/max range" do
        expect { validator.call("hello", { min: 3, max: 10 }) }.not_to raise_error
        expect { validator.call("test",  { min: 3, max: 10 }) }.not_to raise_error
      end

      it "raises ValidationError when value is outside min/max range" do
        expect { validator.call("hi",  { min: 3, max: 10 }) }
          .to raise_error(CMDx::ValidationError, "length must be within 3 and 10")
        expect { validator.call("hello world!",  { min: 3, max: 10 }) }
          .to raise_error(CMDx::ValidationError, "length must be within 3 and 10")
      end

      it "uses custom message when provided" do
        options = { min: 3, max: 10, message: "Invalid range" }

        expect { validator.call("hi", options) }
          .to raise_error(CMDx::ValidationError, "Invalid range")
      end
    end

    context "with is validation" do
      it "allows values with exact length" do
        expect { validator.call("hello", { is: 5 }) }.not_to raise_error
        expect { validator.call("test", { is: 4 }) }.not_to raise_error
      end

      it "raises ValidationError when value has different length" do
        expect { validator.call("hello", { is: 3 }) }
          .to raise_error(CMDx::ValidationError, "length must be 3")
        expect { validator.call("hi", { is: 5 }) }
          .to raise_error(CMDx::ValidationError, "length must be 5")
      end

      it "uses custom is_message when provided" do
        options = { is: 5, is_message: "Must be exactly %{is} characters" }

        expect { validator.call("hello world", options) }
          .to raise_error(CMDx::ValidationError, "Must be exactly 5 characters")
      end

      it "uses custom message when provided" do
        options = { is: 5, message: "Wrong length" }

        expect { validator.call("hello world", options) }
          .to raise_error(CMDx::ValidationError, "Wrong length")
      end
    end

    context "with is_not validation" do
      it "allows values with different length" do
        expect { validator.call("hello", { is_not: 3 }) }.not_to raise_error
        expect { validator.call("hi", { is_not: 5 }) }.not_to raise_error
      end

      it "raises ValidationError when value has forbidden length" do
        expect { validator.call("hello", { is_not: 5 }) }
          .to raise_error(CMDx::ValidationError, "length must not be 5")
        expect { validator.call("test", { is_not: 4 }) }
          .to raise_error(CMDx::ValidationError, "length must not be 4")
      end

      it "uses custom is_not_message when provided" do
        options = { is_not: 5, is_not_message: "Cannot be %{is_not} characters long" }

        expect { validator.call("hello", options) }
          .to raise_error(CMDx::ValidationError, "Cannot be 5 characters long")
      end

      it "uses custom message when provided" do
        options = { is_not: 5, message: "Forbidden length" }

        expect { validator.call("hello", options) }
          .to raise_error(CMDx::ValidationError, "Forbidden length")
      end
    end

    context "with different data types" do
      it "works with arrays" do
        expect { validator.call([1, 2, 3], { min: 2 }) }.not_to raise_error
        expect { validator.call([1], { min: 2 }) }
          .to raise_error(CMDx::ValidationError, "length must be at least 2")
      end

      it "works with hashes" do
        expect { validator.call({ a: 1, b: 2 }, { min: 2 }) }.not_to raise_error
        expect { validator.call({ a: 1 },  { min: 2 }) }
          .to raise_error(CMDx::ValidationError, "length must be at least 2")
      end

      it "works with empty strings" do
        expect { validator.call("",  { min: 1 }) }
          .to raise_error(CMDx::ValidationError, "length must be at least 1")
        expect { validator.call("",  { is: 0 }) }.not_to raise_error
      end

      it "works with empty arrays" do
        expect { validator.call([],  { min: 1 }) }
          .to raise_error(CMDx::ValidationError, "length must be at least 1")
        expect { validator.call([],  { is: 0 }) }.not_to raise_error
      end
    end

    context "with edge cases" do
      it "handles zero length requirements" do
        expect { validator.call("",  { is: 0 }) }.not_to raise_error
        expect { validator.call("",  { max: 0 }) }.not_to raise_error
        expect { validator.call("",  { within: 0..0 }) }.not_to raise_error
      end

      it "handles single character ranges" do
        expect { validator.call("a", { within: 1..1 }) }.not_to raise_error
        expect { validator.call("ab", { within: 1..1 }) }
          .to raise_error(CMDx::ValidationError, "length must be within 1 and 1")
      end

      it "handles large numbers" do
        long_string = "a" * 1000
        expect { validator.call(long_string,  { min: 999 }) }.not_to raise_error
        expect { validator.call(long_string,  { max: 1001 }) }.not_to raise_error
      end
    end

    context "with invalid options" do
      it "raises ArgumentError when no known options are provided" do
        expect { validator.call("hello",  {}) }
          .to raise_error(ArgumentError, "no known length validator options given")
      end

      it "raises ArgumentError when invalid option keys are provided" do
        expect { validator.call("hello",  { invalid: 5 }) }
          .to raise_error(ArgumentError, "no known length validator options given")
      end
    end

    context "with message interpolation" do
      it "interpolates variables in custom messages" do
        options = { min: 5, min_message: "Minimum is %{min}" }
        expect { validator.call("hi", options) }
          .to raise_error(CMDx::ValidationError, "Minimum is 5")
      end

      it "interpolates multiple variables" do
        options = { within: 3..10, within_message: "Range: %{min}-%{max}" }
        expect { validator.call("hi", options) }
          .to raise_error(CMDx::ValidationError, "Range: 3-10")
      end

      it "handles messages without interpolation" do
        options = { min: 5, min_message: "Fixed message" }
        expect { validator.call("hi", options) }
          .to raise_error(CMDx::ValidationError, "Fixed message")
      end
    end
  end

  describe "integration with tasks" do
    let(:task_class) do
      create_simple_task(name: "LengthValidationTask") do
        required :username, type: :string, length: { min: 3, max: 20 }
        optional :password, type: :string, default: "default", length: { min: 8, message: "Password too short" }
        optional :bio, type: :string, default: "", length: { max: 500 }

        def call
          context.validated_user = { username: username, password: password, bio: bio }
        end
      end
    end

    it "validates successfully with valid lengths" do
      result = task_class.call(username: "johndoe", password: "secret123", bio: "Short bio")

      expect(result).to be_success
      expect(result.context.validated_user).to eq({
                                                    username: "johndoe",
                                                    password: "secret123",
                                                    bio: "Short bio"
                                                  })
    end

    it "fails when username is too short" do
      result = task_class.call(username: "jo", password: "validpassword")

      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("username length must be within 3 and 20")
      expect(result.metadata[:messages]).to eq({ username: ["length must be within 3 and 20"] })
    end

    it "fails when username is too long" do
      result = task_class.call(username: "a" * 25, password: "validpassword")

      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("username length must be within 3 and 20")
      expect(result.metadata[:messages]).to eq({ username: ["length must be within 3 and 20"] })
    end

    it "fails when password is too short with custom message" do
      result = task_class.call(username: "johndoe", password: "short")

      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("password Password too short")
      expect(result.metadata[:messages]).to eq({ password: ["Password too short"] })
    end

    it "fails when bio is too long" do
      result = task_class.call(username: "johndoe", password: "validpassword", bio: "a" * 501)

      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("bio length must be at most 500")
      expect(result.metadata[:messages]).to eq({ bio: ["length must be at most 500"] })
    end

    it "validates with exact length requirement" do
      exact_task = create_simple_task(name: "ExactLengthTask") do
        required :code, type: :string, length: { is: 6, message: "Code must be exactly 6 characters" }

        def call
          context.validated_code = code
        end
      end

      expect(exact_task.call(code: "ABC123")).to be_success

      result = exact_task.call(code: "ABC12")
      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("code Code must be exactly 6 characters")
      expect(result.metadata[:messages]).to eq({ code: ["Code must be exactly 6 characters"] })
    end

    it "validates with forbidden length" do
      forbidden_task = create_simple_task(name: "ForbiddenLengthTask") do
        required :input, type: :string, length: { is_not: 13, message: "Superstitious about 13 characters" }

        def call
          context.validated_input = input
        end
      end

      expect(forbidden_task.call(input: "hello world")).to be_success

      result = forbidden_task.call(input: "exactly 13 ch")
      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("input Superstitious about 13 characters")
      expect(result.metadata[:messages]).to eq({ input: ["Superstitious about 13 characters"] })
    end

    it "works with multiple length validations" do
      multi_task = create_simple_task(name: "MultiLengthTask") do
        required :title, type: :string, length: { min: 5, max: 100 }
        required :slug, type: :string, length: { min: 3, max: 50 }
        optional :summary, type: :string, default: "", length: { max: 200 }

        def call
          context.validated_data = { title: title, slug: slug, summary: summary }
        end
      end

      result = multi_task.call(title: "Valid Title", slug: "valid-slug", summary: "A short summary")
      expect(result).to be_success

      result = multi_task.call(title: "Hi", slug: "valid-slug")
      expect(result).to be_failed

      result = multi_task.call(title: "Valid Title", slug: "hi")
      expect(result).to be_failed
    end

    it "handles array length validation" do
      array_task = create_simple_task(name: "ArrayLengthTask") do
        required :tags, type: :array, length: { min: 1, max: 5, message: "Must have 1-5 tags" }

        def call
          context.validated_tags = tags
        end
      end

      expect(array_task.call(tags: %w[ruby rails])).to be_success

      result = array_task.call(tags: [])
      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("tags Must have 1-5 tags")
      expect(result.metadata[:messages]).to eq({ tags: ["Must have 1-5 tags"] })
    end
  end
end
