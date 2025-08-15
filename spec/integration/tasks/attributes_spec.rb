# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task attributes", type: :feature do
  context "when defining" do
    context "without options" do
      context "with no inputs" do
        it "fails due to missing input" do
          task = create_task_class do
            attribute :plain_attr
            required :required_attr
            optional :optional_attr

            def work
              context.attrs = [plain_attr, required_attr, optional_attr]
            end
          end

          result = task.execute

          expect(result).to have_been_failure(
            reason: "required_attr must be accessible via the source",
            metadata: { messages: { required_attr: ["must be accessible via the source"] } },
            cause: be_a(CMDx::FailFault)
          )
        end
      end

      context "with minimum inputs" do
        it "returns attributes defined as methods" do
          task = create_task_class do
            attribute :plain_attr
            required :required_attr
            optional :optional_attr

            def work
              context.attrs = [plain_attr, required_attr, optional_attr]
            end
          end

          result = task.execute(required_attr: "required")

          expect(result).to have_been_success
          expect(result).to have_matching_context(attrs: [nil, "required", nil])
        end
      end

      context "with maximum inputs" do
        it "returns attributes defined as methods" do
          task = create_task_class do
            attribute :plain_attr
            required :required_attr
            optional :optional_attr

            def work
              context.attrs = [plain_attr, required_attr, optional_attr]
            end
          end

          result = task.execute(plain_attr: "plain", required_attr: "required", optional_attr: "optional")

          expect(result).to have_been_success
          expect(result).to have_matching_context(attrs: %w[plain required optional])
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
