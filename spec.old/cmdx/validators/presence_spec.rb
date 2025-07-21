# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Presence do
  subject(:validator) { described_class.new }

  describe ".call" do
    it "creates instance and calls #call method" do
      expect(described_class).to receive(:new).and_return(validator)
      expect(validator).to receive(:call).with("value", {})

      described_class.call("value", {})
    end
  end

  describe "#call" do
    context "with string values" do
      it "allows non-empty strings" do
        expect { validator.call("hello", {}) }.not_to raise_error
      end

      it "allows strings with content" do
        expect { validator.call("test string", {}) }.not_to raise_error
      end

      it "allows strings with numbers" do
        expect { validator.call("123", {}) }.not_to raise_error
      end

      it "raises ValidationError for empty strings" do
        expect { validator.call("",  {}) }
          .to raise_error(CMDx::ValidationError, "cannot be empty")
      end

      it "raises ValidationError for whitespace-only strings" do
        expect { validator.call("   ",  {}) }
          .to raise_error(CMDx::ValidationError, "cannot be empty")
      end

      it "raises ValidationError for tab and newline-only strings" do
        expect { validator.call("\t\n\r ", {}) }
          .to raise_error(CMDx::ValidationError, "cannot be empty")
      end

      it "allows strings with whitespace and content" do
        expect { validator.call("  hello  ", {}) }.not_to raise_error
      end

      it "allows strings with special characters" do
        expect { validator.call("@#$%", {}) }.not_to raise_error
      end
    end

    context "with objects that respond to empty?" do
      it "allows non-empty arrays" do
        expect { validator.call([1, 2, 3],  {}) }.not_to raise_error
      end

      it "allows non-empty hashes" do
        expect { validator.call({ key: "value" }, {}) }.not_to raise_error
      end

      it "raises ValidationError for empty arrays" do
        expect { validator.call([],  {}) }
          .to raise_error(CMDx::ValidationError, "cannot be empty")
      end

      it "raises ValidationError for empty hashes" do
        expect { validator.call({},  {}) }
          .to raise_error(CMDx::ValidationError, "cannot be empty")
      end

      it "allows arrays with nil elements" do
        expect { validator.call([nil, nil], {}) }.not_to raise_error
      end

      it "allows hashes with nil values" do
        expect { validator.call({ key: nil }, {}) }.not_to raise_error
      end
    end

    context "with other objects" do
      it "allows non-nil numeric values" do
        expect { validator.call(42, {}) }.not_to raise_error
        expect { validator.call(0, {}) }.not_to raise_error
        expect { validator.call(-1, {}) }.not_to raise_error
        expect { validator.call(3.14,  {}) }.not_to raise_error
      end

      it "allows boolean values" do
        expect { validator.call(true,  {}) }.not_to raise_error
        expect { validator.call(false, {}) }.not_to raise_error
      end

      it "allows symbols" do
        expect { validator.call(:symbol, {}) }.not_to raise_error
      end

      it "allows objects" do
        expect { validator.call(Object.new,  {}) }.not_to raise_error
      end

      it "raises ValidationError for nil values" do
        expect { validator.call(nil, {}) }
          .to raise_error(CMDx::ValidationError, "cannot be empty")
      end
    end

    context "with custom messages" do
      it "uses custom message when provided" do
        options = { message: "This field is required" }

        expect { validator.call("", options) }
          .to raise_error(CMDx::ValidationError, "This field is required")
      end

      it "uses custom message for nil values" do
        options = { message: "Value cannot be nil" }

        expect { validator.call(nil, options) }
          .to raise_error(CMDx::ValidationError, "Value cannot be nil")
      end

      it "uses custom message for empty arrays" do
        options = { message: "Array must contain items" }

        expect { validator.call([], options) }
          .to raise_error(CMDx::ValidationError, "Array must contain items")
      end

      it "uses custom message for whitespace strings" do
        options = { message: "Please enter valid text" }

        expect { validator.call("   ", options) }
          .to raise_error(CMDx::ValidationError, "Please enter valid text")
      end
    end

    context "with missing options" do
      it "uses default message when no options provided" do
        expect { validator.call("", {}) }
          .to raise_error(CMDx::ValidationError, "cannot be empty")
      end

      it "uses default message when presence option is not a hash" do
        expect { validator.call("", "not a hash") }
          .to raise_error(CMDx::ValidationError, "cannot be empty")
      end

      it "allows valid values when no options provided" do
        expect { validator.call("valid", {}) }.not_to raise_error
      end
    end

    context "with edge cases" do
      it "handles zero as valid presence" do
        expect { validator.call(0, {}) }.not_to raise_error
      end

      it "handles false as valid presence" do
        expect { validator.call(false, {}) }.not_to raise_error
      end

      it "handles empty string within array as valid" do
        expect { validator.call([""], {}) }.not_to raise_error
      end

      it "handles custom objects that respond to empty?" do
        custom_object = Object.new
        def custom_object.empty?
          false
        end

        expect { validator.call(custom_object, {}) }.not_to raise_error
      end

      it "handles custom empty objects" do
        custom_object = Object.new
        def custom_object.empty?
          true
        end

        expect { validator.call(custom_object, {}) }
          .to raise_error(CMDx::ValidationError, "cannot be empty")
      end
    end
  end

  describe "integration with tasks" do
    let(:task_class) do
      create_simple_task(name: "UserValidationTask") do
        required :username, type: :string, presence: {}
        optional :email, type: :string, default: nil, presence: { message: "Email is required" }

        def call
          context.validated_user = { username: username, email: email }
        end
      end
    end

    it "validates successfully with present values" do
      result = task_class.call(username: "johndoe", email: "john@example.com")

      expect(result).to be_success
      expect(result.context.validated_user).to eq({ username: "johndoe", email: "john@example.com" })
    end

    it "fails when required field is empty" do
      result = task_class.call(username: "")

      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("username cannot be empty")
      expect(result.metadata[:messages]).to eq({ username: ["cannot be empty"] })
    end

    it "fails when required field is nil" do
      result = task_class.call(username: nil)

      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("username cannot be empty")
      expect(result.metadata[:messages]).to eq({ username: ["cannot be empty"] })
    end

    it "fails when required field is whitespace only" do
      result = task_class.call(username: "   ")

      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("username cannot be empty")
      expect(result.metadata[:messages]).to eq({ username: ["cannot be empty"] })
    end

    it "fails when optional field with presence validation is empty" do
      result = task_class.call(username: "johndoe", email: "")

      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("email Email is required")
      expect(result.metadata[:messages]).to eq({ email: ["Email is required"] })
    end

    it "validates with array presence" do
      array_task = create_simple_task(name: "ArrayValidationTask") do
        required :tags, type: :array, presence: { message: "Tags cannot be empty" }

        def call
          context.validated_tags = tags
        end
      end

      expect(array_task.call(tags: %w[ruby rails])).to be_success

      result = array_task.call(tags: [])
      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("tags Tags cannot be empty")
      expect(result.metadata[:messages]).to eq({ tags: ["Tags cannot be empty"] })
    end

    it "works with multiple presence validations" do
      multi_task = create_simple_task(name: "MultiValidationTask") do
        required :name, type: :string, presence: {}
        required :description, type: :string, presence: {}

        def call
          context.validated_data = { name: name, description: description }
        end
      end

      result = multi_task.call(name: "Product", description: "A great product")
      expect(result).to be_success

      result = multi_task.call(name: "", description: "Description")
      expect(result).to be_failed

      result = multi_task.call(name: "Product", description: "")
      expect(result).to be_failed
    end

    it "allows false and zero values" do
      boolean_task = create_simple_task(name: "BooleanValidationTask") do
        required :active, type: :boolean, presence: {}
        required :count, type: :integer, presence: {}

        def call
          context.validated_data = { active: active, count: count }
        end
      end

      result = boolean_task.call(active: false, count: 0)
      expect(result).to be_success
      expect(result.context.validated_data).to eq({ active: false, count: 0 })
    end
  end
end
