# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Inclusion do
  subject(:validator) { described_class.new }

  describe ".call" do
    it "creates instance and calls #call method" do
      expect(described_class).to receive(:new).and_return(validator)
      expect(validator).to receive(:call).with("value", { inclusion: { in: ["admin"] } })

      described_class.call("value", { inclusion: { in: ["admin"] } })
    end
  end

  describe "#call" do
    context "with array inclusion" do
      it "allows values in the inclusion array" do
        expect { validator.call("user", { inclusion: { in: %w[user admin] } }) }.not_to raise_error
      end

      it "allows values in the inclusion array using within" do
        expect { validator.call("user", { inclusion: { within: %w[user admin] } }) }.not_to raise_error
      end

      it "raises ValidationError when value is not in inclusion array" do
        expect { validator.call("guest", { inclusion: { in: %w[user admin] } }) }
          .to raise_error(CMDx::ValidationError, 'must be one of: "user", "admin"')
      end

      it "raises ValidationError when value is not in inclusion array using within" do
        expect { validator.call("guest", { inclusion: { within: %w[user admin] } }) }
          .to raise_error(CMDx::ValidationError, 'must be one of: "user", "admin"')
      end

      it "uses custom message when provided" do
        options = { inclusion: { in: %w[user admin], message: "Invalid role selected" } }

        expect { validator.call("guest", options) }
          .to raise_error(CMDx::ValidationError, "Invalid role selected")
      end

      it "uses custom of_message when provided" do
        options = { inclusion: { in: %w[user admin], of_message: "Must be %{values}" } }

        expect { validator.call("guest", options) }
          .to raise_error(CMDx::ValidationError, 'Must be "user", "admin"')
      end

      it "handles empty arrays" do
        expect { validator.call("any_value", { inclusion: { in: [] } }) }
          .to raise_error(CMDx::ValidationError, "must be one of: ")
      end

      it "handles nil inclusion array" do
        expect { validator.call("any_value", { inclusion: { in: nil } }) }
          .to raise_error(CMDx::ValidationError, "must be one of: ")
      end

      it "works with different data types" do
        expect { validator.call(2, { inclusion: { in: [1, 2, 3] } }) }.not_to raise_error
        expect { validator.call(4, { inclusion: { in: [1, 2, 3] } }) }
          .to raise_error(CMDx::ValidationError, "must be one of: 1, 2, 3")
      end

      it "works with symbols" do
        expect { validator.call(:user, { inclusion: { in: %i[user admin] } }) }.not_to raise_error
        expect { validator.call(:guest, { inclusion: { in: %i[user admin] } }) }
          .to raise_error(CMDx::ValidationError, "must be one of: :user, :admin")
      end

      it "works with mixed types" do
        expect { validator.call(1, { inclusion: { in: [1, :admin, "user"] } }) }.not_to raise_error
        expect { validator.call("guest", { inclusion: { in: [1, :admin, "user"] } }) }
          .to raise_error(CMDx::ValidationError, 'must be one of: 1, :admin, "user"')
      end

      it "uses case equality for comparison" do
        expect { validator.call("hello", { inclusion: { in: [/^h/] } }) }.not_to raise_error
        expect { validator.call("world", { inclusion: { in: [/^h/] } }) }
          .to raise_error(CMDx::ValidationError, "must be one of: /^h/")
      end
    end

    context "with range inclusion" do
      it "allows values within the inclusion range" do
        expect { validator.call(5, { inclusion: { in: 1..10 } }) }.not_to raise_error
        expect { validator.call(1, { inclusion: { in: 1..10 } }) }.not_to raise_error
        expect { validator.call(10, { inclusion: { in: 1..10 } }) }.not_to raise_error
      end

      it "allows values within the inclusion range using within" do
        expect { validator.call(5, { inclusion: { within: 1..10 } }) }.not_to raise_error
      end

      it "raises ValidationError when value is outside inclusion range" do
        expect { validator.call(0, { inclusion: { in: 1..10 } }) }
          .to raise_error(CMDx::ValidationError, "must be within 1 and 10")
        expect { validator.call(11, { inclusion: { in: 1..10 } }) }
          .to raise_error(CMDx::ValidationError, "must be within 1 and 10")
      end

      it "raises ValidationError when value is outside inclusion range using within" do
        expect { validator.call(0, { inclusion: { within: 1..10 } }) }
          .to raise_error(CMDx::ValidationError, "must be within 1 and 10")
      end

      it "works with exclusive ranges" do
        expect { validator.call(9, { inclusion: { in: 1...10 } }) }.not_to raise_error
        expect { validator.call(10, { inclusion: { in: 1...10 } }) }
          .to raise_error(CMDx::ValidationError, "must be within 1 and 10")
      end

      it "uses custom message when provided" do
        options = { inclusion: { in: 1..10, message: "Value must be in valid range" } }

        expect { validator.call(15, options) }
          .to raise_error(CMDx::ValidationError, "Value must be in valid range")
      end

      it "uses custom in_message when provided" do
        options = { inclusion: { in: 1..10, in_message: "Must be between %{min} and %{max}" } }

        expect { validator.call(15, options) }
          .to raise_error(CMDx::ValidationError, "Must be between 1 and 10")
      end

      it "uses custom within_message when provided" do
        options = { inclusion: { within: 1..10, within_message: "Should be from %{min} to %{max}" } }

        expect { validator.call(15, options) }
          .to raise_error(CMDx::ValidationError, "Should be from 1 to 10")
      end

      it "works with string ranges" do
        expect { validator.call("m", { inclusion: { in: "a".."z" } }) }.not_to raise_error
        expect { validator.call("1", { inclusion: { in: "a".."z" } }) }
          .to raise_error(CMDx::ValidationError, "must be within a and z")
      end

      it "works with date ranges" do
        start_date = Date.new(2023, 1, 1)
        end_date = Date.new(2023, 12, 31)
        test_date = Date.new(2023, 6, 15)
        outside_date = Date.new(2024, 1, 1)

        expect { validator.call(test_date, { inclusion: { in: start_date..end_date } }) }.not_to raise_error
        expect { validator.call(outside_date, { inclusion: { in: start_date..end_date } }) }
          .to raise_error(CMDx::ValidationError, "must be within #{start_date} and #{end_date}")
      end
    end

    context "with nil values" do
      it "allows nil when included" do
        expect { validator.call(nil, { inclusion: { in: [nil, "admin"] } }) }.not_to raise_error
      end

      it "raises ValidationError when nil is not included" do
        expect { validator.call(nil, { inclusion: { in: %w[user admin] } }) }
          .to raise_error(CMDx::ValidationError, 'must be one of: "user", "admin"')
      end
    end

    context "with missing options" do
      it "raises ValidationError when no inclusion options provided" do
        expect { validator.call("admin", {}) }
          .to raise_error(CMDx::ValidationError, "must be one of: ")
      end

      it "raises ValidationError when inclusion hash is empty" do
        expect { validator.call("admin", { inclusion: {} }) }
          .to raise_error(CMDx::ValidationError, "must be one of: ")
      end

      it "raises ValidationError when both in and within are nil" do
        expect { validator.call("admin", { inclusion: { in: nil, within: nil } }) }
          .to raise_error(CMDx::ValidationError, "must be one of: ")
      end
    end

    context "with precedence" do
      it "prioritizes 'in' over 'within' when both are provided" do
        options = { inclusion: { in: ["admin"], within: ["user"] } }

        expect { validator.call("admin", options) }.not_to raise_error
        expect { validator.call("user", options) }
          .to raise_error(CMDx::ValidationError, 'must be one of: "admin"')
      end

      it "prioritizes specific message over general message" do
        options = {
          inclusion: {
            in: ["admin"],
            message: "General message",
            of_message: "Specific message"
          }
        }

        expect { validator.call("user", options) }
          .to raise_error(CMDx::ValidationError, "Specific message")
      end
    end
  end

  describe "integration with tasks" do
    let(:task_class) do
      create_simple_task(name: "UserValidationTask") do
        required :username, type: :string, inclusion: { in: %w[user admin moderator] }
        optional :role, type: :string, default: "user", inclusion: { in: %w[user admin], message: "Invalid role" }

        def call
          context.validated_user = { username: username, role: role }
        end
      end
    end

    it "validates successfully with allowed values" do
      result = task_class.call(username: "user", role: "admin")

      expect(result).to be_success
      expect(result.context.validated_user).to eq({ username: "user", role: "admin" })
    end

    it "fails when username is not included" do
      result = task_class.call(username: "guest")

      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq('username must be one of: "user", "admin", "moderator"')
      expect(result.metadata[:messages]).to eq({ username: ['must be one of: "user", "admin", "moderator"'] })
    end

    it "fails when role is not included with custom message" do
      result = task_class.call(username: "user", role: "superuser")

      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("role Invalid role")
      expect(result.metadata[:messages]).to eq({ role: ["Invalid role"] })
    end

    it "validates with range inclusion" do
      range_task = create_simple_task(name: "RangeValidationTask") do
        required :age, type: :integer, inclusion: { in: 18..65, message: "Age must be between 18 and 65" }

        def call
          context.validated_age = age
        end
      end

      expect(range_task.call(age: 25)).to be_success
      expect(range_task.call(age: 18)).to be_success
      expect(range_task.call(age: 65)).to be_success

      result = range_task.call(age: 17)
      expect(result).to be_failed
      expect(result.metadata[:reason]).to eq("age Age must be between 18 and 65")
      expect(result.metadata[:messages]).to eq({ age: ["Age must be between 18 and 65"] })
    end

    it "works with multiple inclusion validations" do
      multi_task = create_simple_task(name: "MultiValidationTask") do
        required :status, type: :string, inclusion: { in: %w[active inactive pending] }
        required :priority, type: :string, inclusion: { in: %w[low medium high] }

        def call
          context.validated_data = { status: status, priority: priority }
        end
      end

      result = multi_task.call(status: "active", priority: "high")
      expect(result).to be_success

      result = multi_task.call(status: "deleted", priority: "high")
      expect(result).to be_failed

      result = multi_task.call(status: "active", priority: "urgent")
      expect(result).to be_failed
    end
  end
end
