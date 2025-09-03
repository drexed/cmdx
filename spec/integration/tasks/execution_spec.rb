# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task execution", type: :feature do
  context "when non-bang" do
    subject(:result) { task.execute }

    context "when simple task" do
      context "when successful" do
        let(:task) { create_successful_task }

        it "returns success" do
          expect(result).to have_been_success
          expect(result).to have_matching_context(executed: %i[success])
        end
      end

      context "when skipping" do
        let(:task) { create_skipping_task }

        it "returns skipped" do
          expect(result).to have_been_skipped
          expect(result).to have_empty_context
        end
      end

      context "when failing" do
        let(:task) { create_failing_task }

        it "returns failure" do
          expect(result).to have_been_failure
          expect(result).to have_empty_context
        end
      end

      context "when erroring" do
        let(:task) { create_erroring_task }

        it "returns failure" do
          expect(result).to have_been_failure(
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
            expect(result).to have_been_success
            expect(result).to have_matching_context(executed: %i[inner middle outer])
          end
        end

        context "when skipping" do
          let(:task) { create_nested_task(status: :skipped) }

          it "returns success" do
            expect(result).to have_been_success
            expect(result).to have_matching_context(executed: %i[middle outer])
          end
        end

        context "when failing" do
          let(:task) { create_nested_task(status: :failure) }

          it "returns failure" do
            expect(result).to have_been_success
            expect(result).to have_matching_context(executed: %i[middle outer])
          end
        end

        context "when erroring" do
          let(:task) { create_nested_task(status: :error) }

          it "returns success" do
            expect(result).to have_been_success
            expect(result).to have_matching_context(executed: %i[middle outer])
          end
        end
      end

      context "when throwing" do
        context "when successful" do
          let(:task) { create_nested_task(strategy: :throw) }

          it "returns success" do
            expect(result).to have_been_success
            expect(result).to have_matching_context(executed: %i[inner middle outer])
          end
        end

        context "when skipping" do
          let(:task) { create_nested_task(strategy: :throw, status: :skipped) }

          it "returns skipped" do
            expect(result).to have_been_skipped
            expect(result).to have_empty_context
          end
        end

        context "when failing" do
          let(:task) { create_nested_task(strategy: :throw, status: :failure) }

          it "returns failure" do
            expect(result).to have_been_failure(
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
            expect(result).to have_been_failure(
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
            expect(result).to have_been_success
            expect(result).to have_matching_context(executed: %i[inner middle outer])
          end
        end

        context "when skipping" do
          let(:task) { create_nested_task(strategy: :raise, status: :skipped) }

          it "returns skipped" do
            expect(result).to have_been_success
            expect(result).to have_matching_context(executed: %i[middle outer])
          end
        end

        context "when failing" do
          let(:task) { create_nested_task(strategy: :raise, status: :failure) }

          it "returns failure" do
            expect(result).to have_been_failure(
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
            expect(result).to have_been_failure(
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
            expect(result).to have_been_success
            expect(result).to have_matching_context(executed: %i[inner middle outer])
          end
        end

        context "when skipping" do
          let(:task) { create_nested_task(strategy: :throw_raise, status: :skipped) }

          it "returns skipped" do
            expect(result).to have_been_success
            expect(result).to have_matching_context(executed: %i[middle outer])
          end
        end

        context "when failing" do
          let(:task) { create_nested_task(strategy: :throw_raise, status: :failure) }

          it "returns failure" do
            expect(result).to have_been_failure(
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
            expect(result).to have_been_failure(
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
            expect(result).to have_been_success
            expect(result).to have_matching_context(executed: %i[inner middle outer])
          end
        end

        context "when skipping" do
          let(:task) { create_nested_task(strategy: :raise_throw, status: :skipped) }

          it "returns skipped" do
            expect(result).to have_been_success
            expect(result).to have_matching_context(executed: %i[outer])
          end
        end

        context "when failing" do
          let(:task) { create_nested_task(strategy: :raise_throw, status: :failure) }

          it "returns failure" do
            expect(result).to have_been_failure(
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
            expect(result).to have_been_failure(
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
          expect(result).to have_been_success
          expect(result).to have_matching_context(executed: %i[success])
        end
      end

      context "when skipping" do
        let(:task) { create_skipping_task }

        it "returns skipped" do
          expect(result).to have_been_skipped
          expect(result).to have_empty_context
        end
      end

      context "when failing" do
        let(:task) { create_failing_task }

        it "raise a CMDx::FailFault" do
          expect { result }.to raise_error(CMDx::FailFault, "No reason given")
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
            expect(result).to have_been_success
            expect(result).to have_matching_context(executed: %i[inner middle outer])
          end
        end

        context "when skipping" do
          let(:task) { create_nested_task(status: :skipped) }

          it "returns success" do
            expect(result).to have_been_success
            expect(result).to have_matching_context(executed: %i[middle outer])
          end
        end

        context "when failing" do
          let(:task) { create_nested_task(status: :failure) }

          it "returns failure" do
            expect(result).to have_been_success
            expect(result).to have_matching_context(executed: %i[middle outer])
          end
        end

        context "when erroring" do
          let(:task) { create_nested_task(status: :error) }

          it "returns success" do
            expect(result).to have_been_success
            expect(result).to have_matching_context(executed: %i[middle outer])
          end
        end
      end

      context "when throwing" do
        context "when successful" do
          let(:task) { create_nested_task(strategy: :throw) }

          it "returns success" do
            expect(result).to have_been_success
            expect(result).to have_matching_context(executed: %i[inner middle outer])
          end
        end

        context "when skipping" do
          let(:task) { create_nested_task(strategy: :throw, status: :skipped) }

          it "returns skipped" do
            expect(result).to have_been_skipped
            expect(result).to have_empty_context
          end
        end

        context "when failing" do
          let(:task) { create_nested_task(strategy: :throw, status: :failure) }

          it "raise a CMDx::FailFault" do
            expect { result }.to raise_error(CMDx::FailFault, "No reason given")
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
            expect(result).to have_been_success
            expect(result).to have_matching_context(executed: %i[inner middle outer])
          end
        end

        context "when skipping" do
          let(:task) { create_nested_task(strategy: :raise, status: :skipped) }

          it "returns skipped" do
            expect(result).to have_been_success
            expect(result).to have_matching_context(executed: %i[middle outer])
          end
        end

        context "when failing" do
          let(:task) { create_nested_task(strategy: :raise, status: :failure) }

          it "raise a CMDx::FailFault" do
            expect { result }.to raise_error(CMDx::FailFault, "No reason given")
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
            expect(result).to have_been_success
            expect(result).to have_matching_context(executed: %i[inner middle outer])
          end
        end

        context "when skipping" do
          let(:task) { create_nested_task(strategy: :throw_raise, status: :skipped) }

          it "returns skipped" do
            expect(result).to have_been_success
            expect(result).to have_matching_context(executed: %i[middle outer])
          end
        end

        context "when failing" do
          let(:task) { create_nested_task(strategy: :throw_raise, status: :failure) }

          it "raise a CMDx::FailFault" do
            expect { result }.to raise_error(CMDx::FailFault, "No reason given")
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
            expect(result).to have_been_success
            expect(result).to have_matching_context(executed: %i[inner middle outer])
          end
        end

        context "when skipping" do
          let(:task) { create_nested_task(strategy: :raise_throw, status: :skipped) }

          it "returns skipped" do
            expect(result).to have_been_success
            expect(result).to have_matching_context(executed: %i[outer])
          end
        end

        context "when failing" do
          let(:task) { create_nested_task(strategy: :raise_throw, status: :failure) }

          it "raise a CMDx::FailFault" do
            expect { result }.to raise_error(CMDx::FailFault, "No reason given")
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

  context "when using block" do
    context "when class method" do
      let(:task) { create_successful_task }

      it "yields the result" do
        task.execute do |result|
          expect(result).to have_been_success
          expect(result).to have_matching_context(executed: %i[success])
        end
      end
    end

    context "when instance method" do
      let(:task) { create_successful_task.new }

      it "yields the result" do
        task.execute do |result|
          expect(result).to have_been_success
          expect(result).to have_matching_context(executed: %i[success])
        end
      end
    end
  end
end
