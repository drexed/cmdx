# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task attributes", type: :feature do
  context "when defining" do
    context "without options" do
      context "with no inputs" do
        it "fails due to missing input" do
          task = create_task_class do
            attribute :plain_optional_attr
            attributes :plain_required_attr, required: true
            required :required_attr
            optional :optional_attr

            def work
              context.attrs = [plain_optional_attr, plain_required_attr, required_attr, optional_attr]
            end
          end

          result = task.execute

          expect(result).to have_been_failure(
            reason: "plain_required_attr must be accessible via the source. required_attr must be accessible via the source",
            metadata: {
              messages: {
                plain_required_attr: ["must be accessible via the source"],
                required_attr: ["must be accessible via the source"]
              }
            },
            cause: be_a(CMDx::FailFault)
          )
        end
      end

      context "with minimum inputs" do
        it "returns attributes defined as methods" do
          task = create_task_class do
            attribute :plain_optional_attr
            attributes :plain_required_attr, required: true
            required :required_attr
            optional :optional_attr

            def work
              context.attrs = [plain_optional_attr, plain_required_attr, required_attr, optional_attr]
            end
          end

          result = task.execute(
            plain_required_attr: "plain_required",
            required_attr: "required"
          )

          expect(result).to have_been_success
          expect(result).to have_matching_context(attrs: [nil, "plain_required", "required", nil])
        end
      end

      context "with maximum inputs" do
        it "returns attributes defined as methods" do
          task = create_task_class do
            attribute :plain_optional_attr
            attributes :plain_required_attr, required: true
            required :required_attr
            optional :optional_attr

            def work
              context.attrs = [plain_optional_attr, plain_required_attr, required_attr, optional_attr]
            end
          end

          result = task.execute(
            plain_optional_attr: "plain_optional",
            plain_required_attr: "plain_required",
            required_attr: "required",
            optional_attr: "optional"
          )

          expect(result).to have_been_success
          expect(result).to have_matching_context(attrs: %w[plain_optional plain_required required optional])
        end
      end
    end

    context "with source options" do
      context "when source doesnt exist" do
        it "fails with coercion error message" do
          task = create_task_class do
            attribute :raw_attr, source: :not_a_method

            def work = nil
          end

          result = task.execute

          expect(result).to have_been_failure(
            reason: "raw_attr delegates to undefined method not_a_method",
            metadata: { messages: { raw_attr: ["delegates to undefined method not_a_method"] } },
            cause: be_a(CMDx::FailFault)
          )
        end
      end
    end

    context "with type options" do
      context "when cannot be coerced into type" do
        it "fails with coercion error message" do
          task = create_task_class do
            attribute :raw_attr, type: :integer

            def work = nil
          end

          result = task.execute

          expect(result).to have_been_failure(
            reason: "raw_attr could not coerce into an integer",
            metadata: { messages: { raw_attr: ["could not coerce into an integer"] } },
            cause: be_a(CMDx::FailFault)
          )
        end
      end

      context "when cannot be coerced into any type" do
        it "fails with coercion error message" do
          task = create_task_class do
            attribute :raw_attr, types: %i[float integer]

            def work = nil
          end

          result = task.execute

          expect(result).to have_been_failure(
            reason: "raw_attr could not coerce into one of: float, integer",
            metadata: { messages: { raw_attr: ["could not coerce into one of: float, integer"] } },
            cause: be_a(CMDx::FailFault)
          )
        end
      end

      context "when value can be coerced" do
        it "coerces the value into the type" do
          task = create_task_class do
            attribute :raw_attr, type: :integer

            def work
              context.attrs = [raw_attr]
            end
          end

          result = task.execute(raw_attr: "123")

          expect(result).to have_been_success
          expect(result).to have_matching_context(attrs: [123])
        end
      end
    end

    context "with default option" do
      context "when derived value is nil" do
        it "returns the default value" do
          task = create_task_class do
            attribute :raw_attr, default: 987

            def work
              context.attrs = [raw_attr]
            end
          end

          result = task.execute

          expect(result).to have_been_success
          expect(result).to have_matching_context(attrs: [987])
        end
      end

      context "when derived value is not nil" do
        it "returns the derived value" do
          task = create_task_class do
            attribute :raw_attr, default: 987

            def work
              context.attrs = [raw_attr]
            end
          end

          result = task.execute(raw_attr: "123")

          expect(result).to have_been_success
          expect(result).to have_matching_context(attrs: ["123"])
        end
      end

      context "when the default value cannot be coerced into the type" do
        it "fails with coercion error message" do
          task = create_task_class do
            attribute :raw_attr, type: :integer, default: "abc"

            def work = nil
          end

          result = task.execute

          expect(result).to have_been_failure(
            reason: "raw_attr could not coerce into an integer",
            metadata: { messages: { raw_attr: ["could not coerce into an integer"] } },
            cause: be_a(CMDx::FailFault)
          )
        end
      end
    end

    context "with validation options" do
      context "when value is not valid" do
        it "fails with validation error message" do
          task = create_task_class do
            attribute :raw_attr, format: { with: /^\d+$/ }

            def work = nil
          end

          result = task.execute

          expect(result).to have_been_failure(
            reason: "raw_attr is an invalid format",
            metadata: { messages: { raw_attr: ["is an invalid format"] } },
            cause: be_a(CMDx::FailFault)
          )
        end
      end
    end
  end

  context "when inheriting" do
    it "assumes the parents attributes" do
      parent_task = create_task_class(name: "ParentTask") do
        required :parent_attr

        def work = nil
      end
      child_task = create_task_class(base: parent_task, name: "ChildTask") do
        optional :child_attr

        def work
          context.executed ||= []
          context.executed << parent_attr
          context.executed << child_attr
        end
      end

      result = child_task.execute(parent_attr: "parent123", child_attr: "child456")

      expect(result).to have_been_success
      expect(result).to have_matching_context(executed: %w[parent123 child456])
    end
  end
end
