# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task inheritance", type: :feature do
  describe "#methods" do
    context "when assuming the work method" do
      it "captures the execution order" do
        parent_task = create_task_class(name: "ParentTask") do
          def work = (context.executed ||= []) << :parent
        end
        child_task = create_task_class(base: parent_task, name: "ChildTask")

        result = child_task.execute

        expect(result).to have_been_success
        expect(result).to have_matching_context(executed: %i[parent])
      end
    end

    context "when overriding the work method" do
      it "captures the execution order" do
        parent_task = create_task_class(name: "ParentTask") do
          def work = (context.executed ||= []) << :parent
        end
        child_task = create_task_class(base: parent_task, name: "ChildTask") do
          def work = (context.executed ||= []) << :child
        end

        result = child_task.execute

        expect(result).to have_been_success
        expect(result).to have_matching_context(executed: %i[child])
      end
    end

    context "when super-ing the work method" do
      it "captures the execution order" do
        parent_task = create_task_class(name: "ParentTask") do
          def work = (context.executed ||= []) << :parent
        end
        child_task = create_task_class(base: parent_task, name: "ChildTask") do
          def work
            super
            (context.executed ||= []) << :child
          end
        end

        result = child_task.execute

        expect(result).to have_been_success
        expect(result).to have_matching_context(executed: %i[parent child])
      end
    end
  end

  describe "#attributes" do
    it "inherits the attributes" do
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
