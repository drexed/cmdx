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

        expect(child_task.execute).to have_matching_context(executed: %i[parent])
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

        expect(child_task.execute).to have_matching_context(executed: %i[child])
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

        expect(child_task.execute).to have_matching_context(executed: %i[parent child])
      end
    end
  end
end
