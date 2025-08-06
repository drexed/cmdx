# frozen_string_literal: true

require_relative "../spec_helper"

RSpec.describe "Task execution", type: :feature do
  context "when simple task" do
    context "when successful" do
      let(:task) { create_successful_task }

      it "executes the task with matching attributes" do
        expect(task.execute).to be_success
      end
    end

    context "when skipping" do
      let(:task) { create_skipping_task }

      it "executes the task with matching attributes" do
        expect(task.execute).to be_skipped
      end
    end

    context "when failing" do
      let(:task) { create_failing_task }

      it "executes the task with matching attributes" do
        expect(task.execute).to be_failure
      end
    end

    context "when erroring" do
      let(:task) { create_erroring_task }

      it "executes the task with matching attributes" do
        expect(task.execute).to be_failure
      end
    end
  end
end
