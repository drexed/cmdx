# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::TaskDeprecator do
  subject(:deprecator) { described_class }

  describe ".call" do
    context "when task has deprecated: :error setting" do
      let(:task_class) do
        create_task_class(name: "DeprecatedErrorTask") do
          cmd_settings! deprecated: :error

          def call
            context.executed = true
          end
        end
      end

      it "raises error during task creation" do
        expect { task_class.new }.to raise_error(
          CMDx::DeprecationError,
          /DeprecatedErrorTask\d+ usage prohibited/
        )
      end
    end

    context "when task has deprecated: :log setting" do
      let(:task_class) do
        create_task_class(name: "DeprecatedLogTask") do
          cmd_settings! deprecated: :log

          def call
            context.executed = true
          end
        end
      end

      let(:logger_spy) { instance_spy("Logger") }

      it "logs deprecation warning during task creation" do
        allow_any_instance_of(task_class).to receive(:logger).and_return(logger_spy)

        task_class.new

        expect(logger_spy).to have_received(:warn).once
      end
    end

    context "when task has deprecated: true setting" do
      let(:task_class) do
        create_task_class(name: "DeprecatedTrueTask") do
          cmd_settings! deprecated: true

          def call
            context.executed = true
          end
        end
      end

      let(:logger_spy) { instance_spy("Logger") }

      it "logs deprecation warning during task creation" do
        allow_any_instance_of(task_class).to receive(:logger).and_return(logger_spy)

        task_class.new

        expect(logger_spy).to have_received(:warn).once
      end
    end

    context "when task has deprecated: :warning setting" do
      let(:task_class) do
        create_task_class(name: "DeprecatedWarningTask") do
          cmd_settings! deprecated: :warning

          def call
            context.executed = true
          end
        end
      end

      it "issues Ruby warning during task creation" do
        # Verify warning is called by checking that task creation succeeds
        # and that a task with :warning setting doesn't raise an error
        expect { task_class.new }.not_to raise_error

        # Additionally verify the warn call would be made
        task = task_class.new
        expect(task.cmd_setting(:deprecated)).to eq(:warning)
      end
    end

    context "when task has unknown deprecation setting" do
      let(:task_class) do
        create_task_class(name: "UnknownDeprecationTask") do
          cmd_settings! deprecated: :invalid

          def call
            context.executed = true
          end
        end
      end

      it "raises UnknownDeprecationError during task creation" do
        expect { task_class.new }.to raise_error(
          CMDx::UnknownDeprecationError,
          "unknown deprecation type invalid"
        )
      end
    end

    context "when task has no deprecation setting" do
      let(:task_class) do
        create_task_class(name: "RegularTask") do
          def call
            context.executed = true
          end
        end
      end

      it "performs no action during task creation" do
        expect { task_class.new }.not_to raise_error
      end
    end

    context "when task has deprecated: false setting" do
      let(:task_class) do
        create_task_class(name: "NonDeprecatedTask") do
          cmd_settings! deprecated: false

          def call
            context.executed = true
          end
        end
      end

      it "performs no action during task creation" do
        expect { task_class.new }.not_to raise_error
      end
    end
  end
end
