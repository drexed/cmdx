# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task execution", type: :feature do
  context "when non-bang" do
    subject(:result) { task.execute }

    context "when simple task" do
      context "when successful" do
        let(:task) { create_successful_task }

        it "returns success" do
          expect(result).to be_successful
          expect(result).to have_matching_context(executed: %i[success])
        end
      end

      context "when skipping" do
        let(:task) { create_skipping_task }

        it "returns skipped" do
          expect(result).to have_skipped
          expect(result).to have_empty_context
        end
      end

      context "when failing" do
        let(:task) { create_failing_task }

        it "returns failure" do
          expect(result).to have_failed
          expect(result).to have_empty_context
        end
      end

      context "when erroring" do
        let(:task) { create_erroring_task }

        it "returns failure" do
          expect(result).to have_failed(
            reason: "[CMDx::TestError] borked error",
            cause: be_a(CMDx::TestError)
          )
          expect(result).to have_empty_context
        end
      end
    end

    context "with nested tasks" do
      context "when swallowing" do
        context "when successful" do
          let(:task) { create_nested_task }

          it "returns success" do
            expect(result).to be_successful
            expect(result).to have_matching_context(executed: %i[inner middle outer])
          end
        end

        context "when skipping" do
          let(:task) { create_nested_task(status: :skipped) }

          it "returns success" do
            expect(result).to be_successful
            expect(result).to have_matching_context(executed: %i[middle outer])
          end
        end

        context "when failing" do
          let(:task) { create_nested_task(status: :failure) }

          it "returns failure" do
            expect(result).to be_successful
            expect(result).to have_matching_context(executed: %i[middle outer])
          end
        end

        context "when erroring" do
          let(:task) { create_nested_task(status: :error) }

          it "returns success" do
            expect(result).to be_successful
            expect(result).to have_matching_context(executed: %i[middle outer])
          end
        end
      end

      context "when throwing" do
        context "when successful" do
          let(:task) { create_nested_task(strategy: :throw) }

          it "returns success" do
            expect(result).to be_successful
            expect(result).to have_matching_context(executed: %i[inner middle outer])
          end
        end

        context "when skipping" do
          let(:task) { create_nested_task(strategy: :throw, status: :skipped) }

          it "returns skipped" do
            expect(result).to have_skipped
            expect(result).to have_empty_context
          end
        end

        context "when failing" do
          let(:task) { create_nested_task(strategy: :throw, status: :failure) }

          it "returns failure" do
            expect(result).to have_failed(
              outcome: CMDx::Result::INTERRUPTED,
              threw_failure: hash_including(
                index: 1,
                class: start_with("MiddleTask")
              ),
              caused_failure: hash_including(
                index: 2,
                class: start_with("InnerTask")
              )
            )
            expect(result).to have_empty_context
          end
        end

        context "when erroring" do
          let(:task) { create_nested_task(strategy: :throw, status: :error) }

          it "returns failure" do
            expect(result).to have_failed(
              outcome: CMDx::Result::INTERRUPTED,
              reason: "[CMDx::TestError] borked error",
              threw_failure: hash_including(
                index: 1,
                class: start_with("MiddleTask")
              ),
              caused_failure: hash_including(
                index: 2,
                class: start_with("InnerTask")
              )
            )
            expect(result).to have_empty_context
          end
        end
      end

      context "when raising" do
        context "when successful" do
          let(:task) { create_nested_task(strategy: :raise) }

          it "returns success" do
            expect(result).to be_successful
            expect(result).to have_matching_context(executed: %i[inner middle outer])
          end
        end

        context "when skipping" do
          let(:task) { create_nested_task(strategy: :raise, status: :skipped) }

          it "returns skipped" do
            expect(result).to be_successful
            expect(result).to have_matching_context(executed: %i[middle outer])
          end
        end

        context "when failing" do
          let(:task) { create_nested_task(strategy: :raise, status: :failure) }

          it "returns failure" do
            expect(result).to have_failed(
              outcome: CMDx::Result::INTERRUPTED,
              threw_failure: hash_including(
                index: 1,
                class: start_with("MiddleTask")
              ),
              caused_failure: hash_including(
                index: 2,
                class: start_with("InnerTask")
              )
            )
            expect(result).to have_empty_context
          end
        end

        context "when erroring" do
          let(:task) { create_nested_task(strategy: :raise, status: :error) }

          it "returns failure" do
            expect(result).to have_failed(
              outcome: CMDx::Result::INTERRUPTED,
              reason: "[CMDx::TestError] borked error",
              cause: be_a(CMDx::TestError),
              threw_failure: hash_including(
                index: 1,
                class: start_with("MiddleTask")
              ),
              caused_failure: hash_including(
                index: 2,
                class: start_with("InnerTask")
              )
            )
            expect(result).to have_empty_context
          end
        end
      end

      context "when throw to raise" do
        context "when successful" do
          let(:task) { create_nested_task(strategy: :throw_raise) }

          it "returns success" do
            expect(result).to be_successful
            expect(result).to have_matching_context(executed: %i[inner middle outer])
          end
        end

        context "when skipping" do
          let(:task) { create_nested_task(strategy: :throw_raise, status: :skipped) }

          it "returns skipped" do
            expect(result).to be_successful
            expect(result).to have_matching_context(executed: %i[middle outer])
          end
        end

        context "when failing" do
          let(:task) { create_nested_task(strategy: :throw_raise, status: :failure) }

          it "returns failure" do
            expect(result).to have_failed(
              outcome: CMDx::Result::INTERRUPTED,
              threw_failure: hash_including(
                index: 1,
                class: start_with("MiddleTask")
              ),
              caused_failure: hash_including(
                index: 2,
                class: start_with("InnerTask")
              )
            )
            expect(result).to have_empty_context
          end
        end

        context "when erroring" do
          let(:task) { create_nested_task(strategy: :throw_raise, status: :error) }

          it "returns failure" do
            expect(result).to have_failed(
              outcome: CMDx::Result::INTERRUPTED,
              reason: "[CMDx::TestError] borked error",
              cause: be_a(CMDx::FailFault),
              threw_failure: hash_including(
                index: 1,
                class: start_with("MiddleTask")
              ),
              caused_failure: hash_including(
                index: 2,
                class: start_with("InnerTask")
              )
            )
            expect(result).to have_empty_context
          end
        end
      end

      context "when raise to throw" do
        context "when successful" do
          let(:task) { create_nested_task(strategy: :raise_throw) }

          it "returns success" do
            expect(result).to be_successful
            expect(result).to have_matching_context(executed: %i[inner middle outer])
          end
        end

        context "when skipping" do
          let(:task) { create_nested_task(strategy: :raise_throw, status: :skipped) }

          it "returns skipped" do
            expect(result).to be_successful
            expect(result).to have_matching_context(executed: %i[outer])
          end
        end

        context "when failing" do
          let(:task) { create_nested_task(strategy: :raise_throw, status: :failure) }

          it "returns failure" do
            expect(result).to have_failed(
              outcome: CMDx::Result::INTERRUPTED,
              threw_failure: hash_including(
                index: 1,
                class: start_with("MiddleTask")
              ),
              caused_failure: hash_including(
                index: 2,
                class: start_with("InnerTask")
              )
            )
            expect(result).to have_empty_context
          end
        end

        context "when erroring" do
          let(:task) { create_nested_task(strategy: :raise_throw, status: :error) }

          it "returns failure" do
            expect(result).to have_failed(
              outcome: CMDx::Result::INTERRUPTED,
              reason: "[CMDx::TestError] borked error",
              cause: be_a(CMDx::FailFault),
              threw_failure: hash_including(
                index: 1,
                class: start_with("MiddleTask")
              ),
              caused_failure: hash_including(
                index: 2,
                class: start_with("InnerTask")
              )
            )
            expect(result).to have_empty_context
          end
        end
      end
    end
  end

  context "when bang" do
    subject(:result) { task.execute! }

    context "when simple task" do
      context "when successful" do
        let(:task) { create_successful_task }

        it "returns success" do
          expect(result).to be_successful
          expect(result).to have_matching_context(executed: %i[success])
        end
      end

      context "when skipping" do
        let(:task) { create_skipping_task }

        it "returns skipped" do
          expect(result).to have_skipped
          expect(result).to have_empty_context
        end
      end

      context "when failing" do
        let(:task) { create_failing_task }

        it "raise a CMDx::FailFault" do
          expect { result }.to raise_error(CMDx::FailFault, "Unspecified")
        end
      end

      context "when erroring" do
        let(:task) { create_erroring_task }

        it "raise a CMDx::TestError" do
          expect { result }.to raise_error(CMDx::TestError, "borked error")
        end
      end
    end

    context "with nested tasks" do
      context "when swallowing" do
        context "when successful" do
          let(:task) { create_nested_task }

          it "returns success" do
            expect(result).to be_successful
            expect(result).to have_matching_context(executed: %i[inner middle outer])
          end
        end

        context "when skipping" do
          let(:task) { create_nested_task(status: :skipped) }

          it "returns success" do
            expect(result).to be_successful
            expect(result).to have_matching_context(executed: %i[middle outer])
          end
        end

        context "when failing" do
          let(:task) { create_nested_task(status: :failure) }

          it "returns failure" do
            expect(result).to be_successful
            expect(result).to have_matching_context(executed: %i[middle outer])
          end
        end

        context "when erroring" do
          let(:task) { create_nested_task(status: :error) }

          it "returns success" do
            expect(result).to be_successful
            expect(result).to have_matching_context(executed: %i[middle outer])
          end
        end
      end

      context "when throwing" do
        context "when successful" do
          let(:task) { create_nested_task(strategy: :throw) }

          it "returns success" do
            expect(result).to be_successful
            expect(result).to have_matching_context(executed: %i[inner middle outer])
          end
        end

        context "when skipping" do
          let(:task) { create_nested_task(strategy: :throw, status: :skipped) }

          it "returns skipped" do
            expect(result).to have_skipped
            expect(result).to have_empty_context
          end
        end

        context "when failing" do
          let(:task) { create_nested_task(strategy: :throw, status: :failure) }

          it "raise a CMDx::FailFault" do
            expect { result }.to raise_error(CMDx::FailFault, "Unspecified")
          end
        end

        context "when erroring" do
          let(:task) { create_nested_task(strategy: :throw, status: :error) }

          it "raise a CMDx::FailFault" do
            expect { result }.to raise_error(CMDx::FailFault, "[CMDx::TestError] borked error")
          end
        end
      end

      context "when raising" do
        context "when successful" do
          let(:task) { create_nested_task(strategy: :raise) }

          it "returns success" do
            expect(result).to be_successful
            expect(result).to have_matching_context(executed: %i[inner middle outer])
          end
        end

        context "when skipping" do
          let(:task) { create_nested_task(strategy: :raise, status: :skipped) }

          it "returns skipped" do
            expect(result).to be_successful
            expect(result).to have_matching_context(executed: %i[middle outer])
          end
        end

        context "when failing" do
          let(:task) { create_nested_task(strategy: :raise, status: :failure) }

          it "raise a CMDx::FailFault" do
            expect { result }.to raise_error(CMDx::FailFault, "Unspecified")
          end
        end

        context "when erroring" do
          let(:task) { create_nested_task(strategy: :raise, status: :error) }

          it "raise a CMDx::TestError" do
            expect { result }.to raise_error(CMDx::TestError, "borked error")
          end
        end
      end

      context "when throw to raise" do
        context "when successful" do
          let(:task) { create_nested_task(strategy: :throw_raise) }

          it "returns success" do
            expect(result).to be_successful
            expect(result).to have_matching_context(executed: %i[inner middle outer])
          end
        end

        context "when skipping" do
          let(:task) { create_nested_task(strategy: :throw_raise, status: :skipped) }

          it "returns skipped" do
            expect(result).to be_successful
            expect(result).to have_matching_context(executed: %i[middle outer])
          end
        end

        context "when failing" do
          let(:task) { create_nested_task(strategy: :throw_raise, status: :failure) }

          it "raise a CMDx::FailFault" do
            expect { result }.to raise_error(CMDx::FailFault, "Unspecified")
          end
        end

        context "when erroring" do
          let(:task) { create_nested_task(strategy: :throw_raise, status: :error) }

          it "raise a CMDx::FailFault" do
            expect { result }.to raise_error(CMDx::FailFault, "[CMDx::TestError] borked error")
          end
        end
      end

      context "when raise to throw" do
        context "when successful" do
          let(:task) { create_nested_task(strategy: :raise_throw) }

          it "returns success" do
            expect(result).to be_successful
            expect(result).to have_matching_context(executed: %i[inner middle outer])
          end
        end

        context "when skipping" do
          let(:task) { create_nested_task(strategy: :raise_throw, status: :skipped) }

          it "returns skipped" do
            expect(result).to be_successful
            expect(result).to have_matching_context(executed: %i[outer])
          end
        end

        context "when failing" do
          let(:task) { create_nested_task(strategy: :raise_throw, status: :failure) }

          it "raise a CMDx::FailFault" do
            expect { result }.to raise_error(CMDx::FailFault, "Unspecified")
          end
        end

        context "when erroring" do
          let(:task) { create_nested_task(strategy: :raise_throw, status: :error) }

          it "raise a CMDx::FailFault" do
            expect { result }.to raise_error(CMDx::FailFault, "[CMDx::TestError] borked error")
          end
        end
      end
    end
  end

  context "when inheriting" do
    context "when assuming the work method" do
      it "captures the execution order" do
        parent_task = create_task_class(name: "ParentTask") do
          def work = (context.executed ||= []) << :parent
        end
        child_task = create_task_class(base: parent_task, name: "ChildTask")

        result = child_task.execute

        expect(result).to be_successful
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

        expect(result).to be_successful
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

        expect(result).to be_successful
        expect(result).to have_matching_context(executed: %i[parent child])
      end
    end
  end

  context "when using block" do
    context "when class method" do
      let(:task) { create_successful_task }

      it "yields the result" do
        task.execute do |result|
          expect(result).to be_successful
          expect(result).to have_matching_context(executed: %i[success])
        end
      end
    end

    context "when instance method" do
      let(:task) { create_successful_task.new }

      it "yields the result" do
        task.execute do |result|
          expect(result).to be_successful
          expect(result).to have_matching_context(executed: %i[success])
        end
      end
    end
  end

  describe "durability" do
    context "with any exception" do
      it "retries the task n times after first issue without rerunning the middlewares" do
        counter = instance_double("counter", incr: nil)

        task = create_task_class do
          settings retries: 2
          register :middleware, CMDx::Middlewares::Correlate, id: proc {
            counter.incr
            "abc-123"
          }

          def work
            context.retries ||= 0
            context.retries += 1
            raise CMDx::TestError, "borked error" unless self.class.settings[:retries] < context.retries

            (context.executed ||= []) << :success
          end
        end

        expect(counter).to receive(:incr).once

        result = task.execute

        expect(result).to be_successful
        expect(result).to have_matching_context(retries: 3, executed: %i[success])
        expect(result).to have_matching_metadata(retries: 2)
      end
    end

    context "with a specific exception" do
      it "skips retries if the exception is not in the retry_on setting" do
        counter = instance_double("counter", incr: nil)

        task = create_task_class do
          settings retries: 2, retry_on: RuntimeError
          register :middleware, CMDx::Middlewares::Correlate, id: proc {
            counter.incr
            "abc-123"
          }

          def work
            context.retries ||= 0
            context.retries += 1
            raise CMDx::TestError, "borked error" unless self.class.settings[:retries] < context.retries

            (context.executed ||= []) << :success
          end
        end

        expect(counter).to receive(:incr).once

        result = task.execute

        expect(result).to have_failed(
          reason: "[CMDx::TestError] borked error",
          cause: be_a(CMDx::TestError)
        )
        expect(result).to have_matching_context(retries: 1)
        expect(result).to have_matching_metadata({})
      end
    end
  end

  describe "rollback" do
    context "when rollback is configured" do
      it "calls rollback on failure" do
        task = create_task_class do
          settings rollback_on: :failed

          def work
            fail!("something went wrong")
          end

          def rollback
            (context.rolled_back ||= []) << :yes
          end
        end

        result = task.execute

        expect(result).to have_failed(reason: "something went wrong")
        expect(result).to be_rolled_back
        expect(result.context.rolled_back).to eq([:yes])
      end

      it "calls rollback on skip if configured" do
        task = create_task_class do
          settings rollback_on: %i[failed skipped]

          def work
            skip!("skipping")
          end

          def rollback
            (context.rolled_back ||= []) << :yes
          end
        end

        result = task.execute

        expect(result).to have_skipped(reason: "skipping")
        expect(result).to be_rolled_back
        expect(result.context.rolled_back).to eq([:yes])
      end
    end

    context "when rollback is explicitly disabled" do
      it "does not call rollback" do
        task = create_task_class do
          settings rollback_on: []

          def work
            fail!("something went wrong")
          end

          def rollback
            (context.rolled_back ||= []) << :yes
          end
        end

        result = task.execute

        expect(result).to have_failed(reason: "something went wrong")
        expect(result).not_to be_rolled_back
        expect(result.context.rolled_back).to be_nil
      end
    end

    context "when rollback is configured but status does not match" do
      it "does not call rollback" do
        task = create_task_class do
          settings rollback_on: %i[failed]

          def work
            skip!("skipping")
          end

          def rollback
            (context.rolled_back ||= []) << :yes
          end
        end

        result = task.execute

        expect(result).to have_skipped(reason: "skipping")
        expect(result).not_to be_rolled_back
        expect(result.context.rolled_back).to be_nil
      end
    end
  end
end
