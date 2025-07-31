# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Exclusion do
  subject(:validator) { described_class.new }

  describe ".call" do
    it "creates instance and calls #call method" do
      expect(described_class).to receive(:new).and_return(validator)
      expect(validator).to receive(:call).with("value", { in: ["admin"] })

      described_class.call("value", { in: ["admin"] })
    end
  end

  describe "#call" do
    context "with array exclusion" do
      it "allows values not in the exclusion array" do
        expect { validator.call("user", { in: %w[admin root] }) }.not_to raise_error
      end

      it "allows values not in the exclusion array using within" do
        expect { validator.call("user", { within: %w[admin root] }) }.not_to raise_error
      end

      it "raises ValidationError when value is in exclusion array" do
        expect { validator.call("admin", { in: %w[admin root] }) }
          .to raise_error(CMDx::ValidationError, 'must not be one of: "admin", "root"')
      end

      it "raises ValidationError when value is in exclusion array using within" do
        expect { validator.call("root", { within: %w[admin root] }) }
          .to raise_error(CMDx::ValidationError, 'must not be one of: "admin", "root"')
      end

      it "uses custom message when provided" do
        options = { in: %w[admin root], message: "Reserved username not allowed" }

        expect { validator.call("admin", options) }
          .to raise_error(CMDx::ValidationError, "Reserved username not allowed")
      end

      it "uses custom of_message when provided" do
        options = { in: %w[admin root], of_message: "Cannot be %{values}" }

        expect { validator.call("admin", options) }
          .to raise_error(CMDx::ValidationError, 'Cannot be "admin", "root"')
      end

      it "handles empty arrays" do
        expect { validator.call("any_value", { in: [] }) }.not_to raise_error
      end

      it "handles nil exclusion array" do
        expect { validator.call("any_value", { in: nil }) }.not_to raise_error
      end

      it "works with different data types" do
        expect { validator.call(1, {  in: [2, 3, 4] }) }.not_to raise_error
        expect { validator.call(2, {  in: [2, 3, 4] }) }
          .to raise_error(CMDx::ValidationError, "must not be one of: 2, 3, 4")
      end

      it "works with symbols" do
        expect { validator.call(:user, {  in: %i[admin root] }) }.not_to raise_error
        expect { validator.call(:admin, {  in: %i[admin root] }) }
          .to raise_error(CMDx::ValidationError, "must not be one of: :admin, :root")
      end

      it "works with mixed types" do
        expect { validator.call("test", {  in: [1, :admin, "root"] }) }.not_to raise_error
        expect { validator.call(1, { in: [1, :admin, "root"] }) }
          .to raise_error(CMDx::ValidationError, 'must not be one of: 1, :admin, "root"')
      end

      it "uses case equality for comparison" do
        expect { validator.call("hello", { in: [/^h/] }) }
          .to raise_error(CMDx::ValidationError, "must not be one of: /^h/")
      end
    end

    context "with range exclusion" do
      it "allows values outside the exclusion range" do
        expect { validator.call(0, { in: 1..10 }) }.not_to raise_error
        expect { validator.call(11, { in: 1..10 }) }.not_to raise_error
      end

      it "allows values outside the exclusion range using within" do
        expect { validator.call(0, { within: 1..10 }) }.not_to raise_error
        expect { validator.call(11, { within: 1..10 }) }.not_to raise_error
      end

      it "raises ValidationError when value is within exclusion range" do
        expect { validator.call(5, {  in: 1..10 }) }
          .to raise_error(CMDx::ValidationError, "must not be within 1 and 10")
      end

      it "raises ValidationError when value is within exclusion range using within" do
        expect { validator.call(5, {  within: 1..10 }) }
          .to raise_error(CMDx::ValidationError, "must not be within 1 and 10")
      end

      it "includes range boundaries" do
        expect { validator.call(1, {  in: 1..10 }) }
          .to raise_error(CMDx::ValidationError, "must not be within 1 and 10")
        expect { validator.call(10, {  in: 1..10 }) }
          .to raise_error(CMDx::ValidationError, "must not be within 1 and 10")
      end

      it "works with exclusive ranges" do
        expect { validator.call(10, {  in: 1...10 }) }.not_to raise_error
        expect { validator.call(9, { in: 1...10 }) }
          .to raise_error(CMDx::ValidationError, "must not be within 1 and 10")
      end

      it "uses custom message when provided" do
        options = { in: 1..10, message: "Value not allowed in range" }

        expect { validator.call(5, options) }
          .to raise_error(CMDx::ValidationError, "Value not allowed in range")
      end

      it "uses custom in_message when provided" do
        options = { in: 1..10, in_message: "Must be outside %{min} to %{max}" }

        expect { validator.call(5, options) }
          .to raise_error(CMDx::ValidationError, "Must be outside 1 to 10")
      end

      it "uses custom within_message when provided" do
        options = { within: 1..10, within_message: "Cannot be between %{min} and %{max}" }

        expect { validator.call(5, options) }
          .to raise_error(CMDx::ValidationError, "Cannot be between 1 and 10")
      end

      it "works with string ranges" do
        expect { validator.call("a", {  in: "b".."z" }) }.not_to raise_error
        expect { validator.call("m", {  in: "b".."z" }) }
          .to raise_error(CMDx::ValidationError, "must not be within b and z")
      end

      it "works with date ranges" do
        start_date = Date.new(2023, 1, 1)
        end_date = Date.new(2023, 12, 31)
        test_date = Date.new(2023, 6, 15)

        expect { validator.call(test_date, { in: start_date..end_date }) }
          .to raise_error(CMDx::ValidationError, "must not be within #{start_date} and #{end_date}")
      end
    end

    context "with nil values" do
      it "allows nil when not excluded" do
        expect { validator.call(nil, {  in: %w[admin root] }) }.not_to raise_error
      end

      it "raises ValidationError when nil is explicitly excluded" do
        expect { validator.call(nil, {  in: [nil, "admin"] }) }
          .to raise_error(CMDx::ValidationError, 'must not be one of: nil, "admin"')
      end
    end

    context "with missing options" do
      it "allows any value when no exclusion options provided" do
        expect { validator.call("admin", {}) }.not_to raise_error
      end

      it "allows any value when both in and within are nil" do
        expect { validator.call("admin", {  in: nil, within: nil }) }.not_to raise_error
      end
    end

    context "with precedence" do
      it "prioritizes 'in' over 'within' when both are provided" do
        options = { in: ["admin"], within: ["root"] }

        expect { validator.call("admin", options) }
          .to raise_error(CMDx::ValidationError, 'must not be one of: "admin"')
        expect { validator.call("root", options) }.not_to raise_error
      end

      it "prioritizes specific message over general message" do
        options = {

          in: ["admin"],
          message: "General message",
          of_message: "Specific message"

        }

        expect { validator.call("admin", options) }
          .to raise_error(CMDx::ValidationError, "Specific message")
      end
    end
  end

  describe "integration with tasks" do
    let(:task_class) do
      create_simple_task(name: "UserValidationTask") do
        required :username, type: :string, exclusion: { in: %w[admin root system] }
        optional :role, type: :string, default: "user", exclusion: { in: ["superuser"], message: "Role not allowed" }

        def call
          context.validated_user = { username: username, role: role }
        end
      end
    end

    it "validates successfully with allowed values" do
      result = task_class.call(username: "johndoe", role: "user")

      expect(result).to be_success
      expect(result.context.validated_user).to eq({ username: "johndoe", role: "user" })
    end

    it "fails when username is excluded" do
      result = task_class.call(username: "admin")

      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq('username must not be one of: "admin", "root", "system"')
      expect(result.metadata[:messages]).to eq({ username: ['must not be one of: "admin", "root", "system"'] })
    end

    it "fails when role is excluded with custom message" do
      result = task_class.call(username: "johndoe", role: "superuser")

      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("role Role not allowed")
      expect(result.metadata[:messages]).to eq({ role: ["Role not allowed"] })
    end

    it "validates with range exclusion" do
      range_task = create_simple_task(name: "RangeValidationTask") do
        required :age, type: :integer, exclusion: { in: 13..17, message: "Age not allowed for this service" }

        def call
          context.validated_age = age
        end
      end

      expect(range_task.call(age: 12)).to be_success
      expect(range_task.call(age: 18)).to be_success

      result = range_task.call(age: 15)
      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("age Age not allowed for this service")
      expect(result.metadata[:messages]).to eq({ age: ["Age not allowed for this service"] })
    end

    it "works with multiple exclusion validations" do
      multi_task = create_simple_task(name: "MultiValidationTask") do
        required :username, type: :string,  exclusion: { in: %w[admin root] }
        required :email, type: :string, exclusion: { in: ["admin@example.com", "root@example.com"] }

        def call
          context.validated_data = { username: username, email: email }
        end
      end

      result = multi_task.call(username: "user", email: "user@example.com")
      expect(result).to be_success

      result = multi_task.call(username: "admin", email: "user@example.com")
      expect(result).to be_failed

      result = multi_task.call(username: "user", email: "admin@example.com")
      expect(result).to be_failed
    end
  end
end
