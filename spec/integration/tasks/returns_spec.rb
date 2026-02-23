# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task returns", type: :feature do
  context "when declaring" do
    context "with no returns" do
      it "does not validate returns" do
        task = create_task_class do
          def work
            (context.executed ||= []) << :success
          end
        end

        result = task.execute

        expect(result).to be_successful
        expect(result).to have_matching_context(executed: %i[success])
      end
    end

    context "with single return" do
      context "when return is present" do
        it "returns success" do
          task = create_task_class do
            returns :user

            def work
              context.user = "John"
            end
          end

          result = task.execute

          expect(result).to be_successful
          expect(result).to have_matching_context(user: "John")
        end
      end

      context "when return is missing" do
        it "returns failure" do
          task = create_task_class do
            returns :user

            def work
              (context.executed ||= []) << :success
            end
          end

          result = task.execute

          expect(result).to have_failed(
            reason: "Invalid",
            cause: be_a(CMDx::FailFault)
          )
          expect(result).to have_matching_metadata(
            errors: {
              full_message: "user must be set in the context",
              messages: { user: ["must be set in the context"] }
            }
          )
        end
      end
    end

    context "with multiple returns" do
      context "when all returns are present" do
        it "returns success" do
          task = create_task_class do
            returns :user, :token

            def work
              context.user = "John"
              context.token = "abc123"
            end
          end

          result = task.execute

          expect(result).to be_successful
          expect(result).to have_matching_context(user: "John", token: "abc123")
        end
      end

      context "when some returns are missing" do
        it "returns failure with all missing returns" do
          task = create_task_class do
            returns :user, :token

            def work
              context.user = "John"
            end
          end

          result = task.execute

          expect(result).to have_failed(
            reason: "Invalid",
            cause: be_a(CMDx::FailFault)
          )
          expect(result).to have_matching_metadata(
            errors: {
              full_message: "token must be set in the context",
              messages: { token: ["must be set in the context"] }
            }
          )
        end
      end

      context "when all returns are missing" do
        it "returns failure with all missing returns" do
          task = create_task_class do
            returns :user, :token

            def work = nil
          end

          result = task.execute

          expect(result).to have_failed(
            reason: "Invalid",
            cause: be_a(CMDx::FailFault)
          )
          expect(result).to have_matching_metadata(
            errors: {
              full_message: "user must be set in the context. token must be set in the context",
              messages: {
                user: ["must be set in the context"],
                token: ["must be set in the context"]
              }
            }
          )
        end
      end
    end
  end

  context "when task skips" do
    it "does not validate returns" do
      task = create_task_class do
        returns :user

        def work
          skip!("not needed")
        end
      end

      result = task.execute

      expect(result).to have_skipped(reason: "not needed")
    end
  end

  context "when task fails" do
    it "does not validate returns" do
      task = create_task_class do
        returns :user

        def work
          fail!("something went wrong")
        end
      end

      result = task.execute

      expect(result).to have_failed(reason: "something went wrong")
    end
  end

  context "when using bang execution" do
    context "when return is missing" do
      it "raises a CMDx::FailFault" do
        task = create_task_class do
          returns :user

          def work = nil
        end

        expect { task.execute! }.to raise_error(CMDx::FailFault, "Invalid")
      end
    end

    context "when return is present" do
      it "returns success" do
        task = create_task_class do
          returns :user

          def work
            context.user = "John"
          end
        end

        result = task.execute!

        expect(result).to be_successful
        expect(result).to have_matching_context(user: "John")
      end
    end
  end

  context "when inheriting" do
    it "inherits parent returns" do
      parent_task = create_task_class(name: "ParentTask") do
        returns :user

        def work
          context.user = "John"
        end
      end
      child_task = create_task_class(base: parent_task, name: "ChildTask") do
        returns :token

        def work
          super
          context.token = "abc123"
        end
      end

      result = child_task.execute

      expect(result).to be_successful
      expect(result).to have_matching_context(user: "John", token: "abc123")
    end

    it "fails when inherited return is missing" do
      parent_task = create_task_class(name: "ParentTask") do
        returns :user

        def work
          context.user = "John"
        end
      end
      child_task = create_task_class(base: parent_task, name: "ChildTask") do
        returns :token
      end

      result = child_task.execute

      expect(result).to have_failed(
        reason: "Invalid",
        cause: be_a(CMDx::FailFault)
      )
      expect(result).to have_matching_metadata(
        errors: {
          full_message: "token must be set in the context",
          messages: { token: ["must be set in the context"] }
        }
      )
    end
  end

  context "when removing returns" do
    it "removes inherited returns" do
      parent_task = create_task_class(name: "ParentTask") do
        returns :user, :token

        def work
          context.user = "John"
          context.token = "abc123"
        end
      end
      child_task = create_task_class(base: parent_task, name: "ChildTask") do
        remove_return :token

        def work
          context.user = "John"
        end
      end

      result = child_task.execute

      expect(result).to be_successful
      expect(result).to have_matching_context(user: "John")
    end
  end

  context "with attributes and returns" do
    context "when attribute validation fails" do
      it "does not validate returns" do
        task = create_task_class do
          required :name
          returns :user

          def work
            context.user = name
          end
        end

        result = task.execute

        expect(result).to have_failed(
          reason: "Invalid",
          cause: be_a(CMDx::FailFault)
        )
        expect(result).to have_matching_metadata(
          errors: {
            full_message: "name must be accessible via the source",
            messages: { name: ["must be accessible via the source"] }
          }
        )
      end
    end

    context "when attribute validation passes but return is missing" do
      it "fails due to missing return" do
        task = create_task_class do
          required :name
          returns :user

          def work = nil
        end

        result = task.execute(name: "John")

        expect(result).to have_failed(
          reason: "Invalid",
          cause: be_a(CMDx::FailFault)
        )
        expect(result).to have_matching_metadata(
          errors: {
            full_message: "user must be set in the context",
            messages: { user: ["must be set in the context"] }
          }
        )
      end
    end

    context "when both attribute and return are valid" do
      it "returns success" do
        task = create_task_class do
          required :name
          returns :user

          def work
            context.user = { name: name }
          end
        end

        result = task.execute(name: "John")

        expect(result).to be_successful
        expect(result).to have_matching_context(user: { name: "John" })
      end
    end
  end
end
