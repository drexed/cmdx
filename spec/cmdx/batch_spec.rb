# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Batch do
  subject(:batch) { simulation_batch.call }

  describe "#call" do
    context "with invalid task" do
      let(:simulation_batch) do
        Class.new(SimulationBatch) do
          process SimulationTask
          process Struct
        end
      end

      it "raises an TypeError" do
        expect { batch }.to raise_error(TypeError, "must be a Task or Batch")
      end
    end

    context "without failed" do
      let(:simulation_batch) do
        Class.new(SimulationBatch) do
          process SimulationTask
          process SimulationTask, SimulationTask
        end
      end

      it "processes all tasks" do
        expect(batch.context.results).to contain_exactly(
          "SimulationBatch.success",
          "SimulationTask.success",
          "SimulationTask.success",
          "SimulationTask.success"
        )
      end
    end

    context "with conditional" do
      let(:simulation_batch) do
        Class.new(SimulationBatch) do
          process SimulationTask
          process SimulationTask, if: proc { 1 + 1 == 2 }
          process SimulationTask, if: -> { 1 + 1 == 3 }
          process SimulationTask, unless: :skip_task?

          private

          def skip_task?
            true
          end
        end
      end

      it "skips execution of failed conditional" do
        expect(batch.context.results).to contain_exactly(
          "SimulationBatch.success",
          "SimulationTask.success",
          "SimulationTask.success"
        )
      end
    end

    context "with skipped" do
      before { allow_any_instance_of(CMDx::Context).to receive(:simulate).and_return(:success, :skipped, :success) }

      context "without skipped batch_halt option" do
        let(:simulation_batch) do
          Class.new(SimulationBatch) do
            process SimulationTask
            process SimulationTask
            process SimulationTask
          end
        end

        it "keeps executing even if a skip happens" do
          expect(batch.context.results).to contain_exactly(
            "SimulationBatch.success",
            "SimulationTask.success",
            "SimulationTask.skipped",
            "SimulationTask.success"
          )
        end
      end

      context "with skipped batch_halt option" do
        let(:simulation_batch) do
          Class.new(SimulationBatch) do
            task_settings!(batch_halt: [CMDx::Result::SKIPPED])

            process SimulationTask
            process SimulationTask
            process SimulationTask
          end
        end

        it "stops execution if a skip happens" do
          expect(batch.context.results).to contain_exactly(
            "SimulationBatch.skipped",
            "SimulationTask.success",
            "SimulationTask.skipped"
          )
        end
      end

      context "with batch_halt process level" do
        let(:simulation_batch) do
          Class.new(SimulationBatch) do
            process SimulationTask
            process SimulationTask, batch_halt: [CMDx::Result::SKIPPED]
            process SimulationTask
          end
        end

        it "stops execution if a skip happens" do
          expect(batch.context.results).to contain_exactly(
            "SimulationBatch.skipped",
            "SimulationTask.success",
            "SimulationTask.skipped"
          )
        end
      end
    end

    context "with failed" do
      let(:simulation_batch) do
        Class.new(SimulationBatch) do
          process SimulationTask
          process SimulationTask
          process SimulationTask
        end
      end

      before { allow_any_instance_of(CMDx::Context).to receive(:simulate).and_return(:success, :failed, :success) }

      it "stops execution if a failed happens" do
        expect(batch.context.results).to contain_exactly(
          "SimulationBatch.failed",
          "SimulationTask.success",
          "SimulationTask.failed"
        )
      end
    end
  end
end
