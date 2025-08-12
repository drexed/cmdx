# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Workflow execution", type: :feature do
  context "when non-blocking" do
    subject(:result) { workflow.execute }

    context "when successful" do
      let(:workflow) { create_successful_workflow }

      it "returns success" do
        expect(result).to have_been_success
        expect(result).to have_matching_context(executed: %i[success inner middle outer success])
      end
    end

    context "when skipping" do
      let(:workflow) { create_skipping_workflow }

      it "returns success" do
        expect(result).to have_been_success
        expect(result).to have_matching_context(executed: %i[success success])
      end
    end

    context "when failing" do
      let(:workflow) { create_failing_workflow }

      it "returns failure" do
        expect(result).to have_been_failure(
          outcome: CMDx::Result::INTERRUPTED,
          threw_failure: hash_including(
            index: 2,
            class: start_with("OuterTask")
          ),
          caused_failure: hash_including(
            index: 4,
            class: start_with("InnerTask")
          )
        )
        expect(result).to have_matching_context(executed: %i[success])
      end
    end

    context "when erroring" do
      let(:workflow) { create_erroring_workflow }

      it "returns failure" do
        expect(result).to have_been_failure(
          outcome: CMDx::Result::INTERRUPTED,
          reason: "[CMDx::TestError] borked error",
          cause: be_a(CMDx::FailFault),
          threw_failure: hash_including(
            index: 2,
            class: start_with("OuterTask")
          ),
          caused_failure: hash_including(
            index: 4,
            class: start_with("InnerTask")
          )
        )
        expect(result).to have_matching_context(executed: %i[success])
      end
    end
  end

  context "when blocking" do
    subject(:result) { workflow.execute! }

    context "when successful" do
      let(:workflow) { create_successful_workflow }

      it "returns success" do
        expect(result).to have_been_success
        expect(result).to have_matching_context(executed: %i[success inner middle outer success])
      end
    end

    context "when skipping" do
      let(:workflow) { create_skipping_workflow }

      it "returns success" do
        expect(result).to have_been_success
        expect(result).to have_matching_context(executed: %i[success success])
      end
    end

    context "when failing" do
      let(:workflow) { create_failing_workflow }

      it "returns failure" do
        expect { result }.to raise_error(CMDx::FailFault, "no reason given")
      end
    end

    context "when erroring" do
      let(:workflow) { create_erroring_workflow }

      it "returns failure" do
        expect { result }.to raise_error(CMDx::FailFault, "[CMDx::TestError] borked error")
      end
    end
  end
end
