# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task execution", type: :feature do
  subject(:result) { task.execute }

  context "when simple task" do
    context "when successful" do
      let(:task) { create_successful_task }

      it "executes the task with matching attributes" do
        expect(result).to have_been_success
      end
    end

    context "when skipping" do
      let(:task) { create_skipping_task }

      it "executes the task with matching attributes" do
        expect(result).to have_been_skipped
      end
    end

    context "when failing" do
      let(:task) { create_failing_task }

      it "executes the task with matching attributes" do
        expect(result).to have_been_failure
      end
    end

    context "when erroring" do
      let(:task) { create_erroring_task }

      it "executes the task with matching attributes" do
        expect(result).to have_been_failure(
          reason: "[StandardError] system error",
          cause: be_a(StandardError)
        )
      end
    end
  end

  context "with nested tasks" do
    context "when swallowing" do
      context "when successful" do
        let(:task) { create_nested_task }

        it "returns success" do
          expect(result).to have_been_success
        end
      end

      context "when skipping" do
        let(:task) { create_nested_task(status: :skipped) }

        it "returns success" do
          expect(result).to have_been_success
        end
      end

      context "when failing" do
        let(:task) { create_nested_task(status: :failure) }

        it "returns failure" do
          expect(result).to have_been_success
        end
      end

      context "when erroring" do
        let(:task) { create_nested_task(status: :error) }

        it "returns success" do
          expect(result).to have_been_success
        end
      end
    end

    context "when throwing" do
      context "when successful" do
        let(:task) { create_nested_task(strategy: :throw) }

        it "returns success" do
          expect(result).to have_been_success
        end
      end

      context "when skipping" do
        let(:task) { create_nested_task(strategy: :throw, status: :skipped, reason: "skipping issue") }

        it "returns success" do
          expect(result).to have_been_skipped(
            reason: "skipping issue"
          )
        end
      end

      context "when failing" do
        let(:task) { create_nested_task(strategy: :throw, status: :failure, reason: "failing issue") }

        it "returns failure" do
          expect(result).to have_been_failure(
            outcome: CMDx::Result::INTERRUPTED,
            reason: "failing issue",
            cause: be_a(StandardError), # This should be filled
            threw_failure: hash_including(
              index: 1,
              class: start_with("MiddleTask")
            ),
            caused_failure: hash_including(
              index: 2,
              class: start_with("InnerTask")
            )
          )
        end
      end

      context "when erroring" do
        let(:task) { create_nested_task(strategy: :throw, status: :error) }

        it "returns failure" do
          expect(result).to have_been_failure(
            outcome: CMDx::Result::INTERRUPTED,
            reason: "[StandardError] system error",
            cause: be_a(StandardError),
            threw_failure: hash_including(
              index: 1,
              class: start_with("MiddleTask")
            ),
            caused_failure: hash_including(
              index: 2,
              class: start_with("InnerTask")
            )
          )
        end
      end
    end
  end
end
