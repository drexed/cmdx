# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task Deprecation", type: :integration do
  describe "Deprecated Task Integration" do
    let(:working_task) do
      Class.new(CMDx::Task) do
        def self.name
          "WorkingTask"
        end

        required :user_id, type: :integer

        def call
          context.user_processed = true
          context.user_id = user_id
        end
      end
    end

    let(:deprecated_task) do
      Class.new(CMDx::Task) do
        def self.name
          "DeprecatedUserTask"
        end

        cmd_settings!(deprecated: true)
        required :user_id, type: :integer

        def call
          context.user_processed = true
          context.user_id = user_id
        end
      end
    end

    context "when using deprecated tasks directly" do
      it "prevents task instantiation" do
        expect { deprecated_task.new(user_id: 123) }.to raise_error(
          CMDx::DeprecationError,
          "DeprecatedUserTask is deprecated"
        )
      end

      it "prevents task calling" do
        expect { deprecated_task.call(user_id: 123) }.to raise_error(
          CMDx::DeprecationError,
          "DeprecatedUserTask is deprecated"
        )
      end

      it "prevents task calling with bang method" do
        expect { deprecated_task.call!(user_id: 123) }.to raise_error(
          CMDx::DeprecationError,
          "DeprecatedUserTask is deprecated"
        )
      end
    end

    context "when using non-deprecated tasks" do
      it "allows normal task instantiation" do
        expect { working_task.new(user_id: 123) }.not_to raise_error
      end

      it "allows normal task calling" do
        result = working_task.call(user_id: 123)
        expect(result).to be_successful_task
        expect(result.context.user_processed).to be(true)
        expect(result.context.user_id).to eq(123)
      end

      it "allows normal task calling with bang method" do
        result = working_task.call!(user_id: 123)
        expect(result).to be_successful_task
        expect(result.context.user_processed).to be(true)
        expect(result.context.user_id).to eq(123)
      end
    end

    context "when using deprecated tasks in workflows" do
      let(:workflow_with_deprecated_task) do
        deprecated = deprecated_task
        working = working_task

        Class.new(CMDx::Workflow) do
          process working
          process deprecated
        end
      end

      it "prevents workflow execution due to deprecated task" do
        expect { workflow_with_deprecated_task.call(user_id: 123) }.to raise_error(
          CMDx::DeprecationError,
          "DeprecatedUserTask is deprecated"
        )
      end

      it "prevents workflow execution even with bang method" do
        expect { workflow_with_deprecated_task.call!(user_id: 123) }.to raise_error(
          CMDx::DeprecationError,
          "DeprecatedUserTask is deprecated"
        )
      end
    end

    context "when using mixed deprecated and non-deprecated tasks" do
      let(:mixed_workflow) do
        working = working_task
        deprecated = deprecated_task

        Class.new(CMDx::Workflow) do
          process working
          process deprecated
        end
      end

      it "fails at the deprecated task step" do
        expect { mixed_workflow.call(user_id: 123) }.to raise_error(
          CMDx::DeprecationError,
          "DeprecatedUserTask is deprecated"
        )
      end

      it "does not execute subsequent tasks after deprecated task" do
        expect { mixed_workflow.call(user_id: 123) }.to raise_error(CMDx::DeprecationError)
      end
    end
  end

  describe "Deprecation with Different Settings" do
    let(:task_with_deprecation_reason) do
      Class.new(CMDx::Task) do
        def self.name
          "TaskWithReason"
        end

        cmd_settings!(deprecated: "Use NewTask instead")
        required :data, type: :string

        def call
          context.processed = true
        end
      end
    end

    let(:task_with_deprecation_metadata) do
      Class.new(CMDx::Task) do
        def self.name
          "TaskWithMetadata"
        end

        cmd_settings!(deprecated: { reason: "Legacy API", replacement: "NewApiTask" })
        required :data, type: :string

        def call
          context.processed = true
        end
      end
    end

    context "when deprecated setting has additional information" do
      it "still prevents task instantiation with reason string" do
        expect { task_with_deprecation_reason.new(data: "test") }.to raise_error(
          CMDx::DeprecationError,
          "TaskWithReason is deprecated"
        )
      end

      it "still prevents task instantiation with metadata hash" do
        expect { task_with_deprecation_metadata.new(data: "test") }.to raise_error(
          CMDx::DeprecationError,
          "TaskWithMetadata is deprecated"
        )
      end
    end
  end

  describe "Deprecation in Complex Workflows" do
    let(:setup_task) do
      Class.new(CMDx::Task) do
        def self.name
          "SetupTask"
        end

        required :project_id, type: :integer

        def call
          context.project_setup = true
          context.project_id = project_id
        end
      end
    end

    let(:legacy_processor) do
      Class.new(CMDx::Task) do
        def self.name
          "LegacyProcessor"
        end

        cmd_settings!(deprecated: true)
        required :project_id, type: :integer

        def call
          context.legacy_processed = true
        end
      end
    end

    let(:cleanup_task) do
      Class.new(CMDx::Task) do
        def self.name
          "CleanupTask"
        end

        required :project_id, type: :integer

        def call
          context.cleanup_done = true
        end
      end
    end

    let(:complex_workflow) do
      setup = setup_task
      legacy = legacy_processor
      cleanup = cleanup_task

      Class.new(CMDx::Workflow) do
        process setup
        process legacy
        process cleanup
      end
    end

    context "when deprecated task is in middle of workflow" do
      it "prevents workflow execution" do
        expect { complex_workflow.call(project_id: 456) }.to raise_error(
          CMDx::DeprecationError,
          "LegacyProcessor is deprecated"
        )
      end

      it "does not execute setup task due to early deprecation check" do
        expect { complex_workflow.call(project_id: 456) }.to raise_error(CMDx::DeprecationError)
      end
    end
  end

  describe "Deprecation Error Handling" do
    let(:deprecated_with_callbacks) do
      Class.new(CMDx::Task) do
        def self.name
          "DeprecatedWithCallbacks"
        end

        cmd_settings!(deprecated: true)

        before_execution :setup_callback
        after_execution :cleanup_callback

        required :data, type: :string

        def call
          context.processed = true
        end

        private

        def setup_callback
          context.setup_called = true
        end

        def cleanup_callback
          context.cleanup_called = true
        end
      end
    end

    context "when deprecated task has callbacks" do
      it "prevents task instantiation before callbacks are executed" do
        expect { deprecated_with_callbacks.new(data: "test") }.to raise_error(
          CMDx::DeprecationError,
          "DeprecatedWithCallbacks is deprecated"
        )
      end

      it "prevents task execution with call method" do
        expect { deprecated_with_callbacks.call(data: "test") }.to raise_error(
          CMDx::DeprecationError,
          "DeprecatedWithCallbacks is deprecated"
        )
      end
    end
  end
end
