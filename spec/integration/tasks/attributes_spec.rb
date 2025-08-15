# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task attributes", type: :feature do
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
