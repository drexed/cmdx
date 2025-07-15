# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Middlewares::Timeout do
  subject(:middleware) { described_class.new(options) }

  let(:options) { {} }
  let(:task) { task_class.new }
  let(:task_class) { create_simple_task }
  let(:callable) do
    lambda { |_task|
      sleep(0.1)
      "result"
    }
  end

  describe "#initialize" do
    context "with default options" do
      it "sets default timeout to 3 seconds" do
        expect(middleware.seconds).to eq(3)
      end

      it "sets empty conditional options" do
        expect(middleware.conditional).to eq({})
      end
    end

    context "with custom seconds" do
      let(:options) { { seconds: 10 } }

      it "sets custom timeout value" do
        expect(middleware.seconds).to eq(10)
      end
    end

    context "with conditional options" do
      let(:options) { { seconds: 5, if: :should_timeout?, unless: :skip_timeout? } }

      it "extracts conditional options" do
        expect(middleware.conditional).to eq(if: :should_timeout?, unless: :skip_timeout?)
      end
    end

    context "with proc timeout" do
      let(:timeout_proc) { -> { 15 } }
      let(:options) { { seconds: timeout_proc } }

      it "stores proc as timeout value" do
        expect(middleware.seconds).to eq(timeout_proc)
      end
    end
  end

  describe "#call" do
    context "when task execution completes within timeout" do
      let(:options) { { seconds: 1 } }

      it "returns the result of the callable" do
        result = middleware.call(task, callable)
        expect(result).to eq("result")
      end

      it "does not modify the task" do
        expect { middleware.call(task, callable) }.not_to change(task, :result)
      end
    end

    context "when task execution exceeds timeout" do
      let(:options) { { seconds: 0.05 } }
      let(:slow_callable) do
        lambda { |_task|
          sleep(0.2)
          "slow result"
        }
      end

      it "raises TimeoutError and fails the task" do
        middleware.call(task, slow_callable)

        expect(task.result).to be_failed
        expect(task.result.metadata[:reason]).to match(/TimeoutError.*execution exceeded 0.05 seconds/)
        expect(task.result.metadata[:original_exception]).to be_a(CMDx::TimeoutError)
        expect(task.result.metadata[:seconds]).to eq(0.05)
      end

      it "returns the failed task result" do
        result = middleware.call(task, slow_callable)
        expect(result).to eq(task.result)
      end
    end

    context "with conditional execution" do
      let(:task_class) do
        create_simple_task do
          def should_timeout?
            @should_timeout || false
          end

          attr_writer :should_timeout

          def skip_timeout?
            @skip_timeout || false
          end

          attr_writer :skip_timeout
        end
      end

      context "with :if condition" do
        let(:options) { { seconds: 0.05, if: :should_timeout? } }

        it "applies timeout when condition is truthy" do
          task.should_timeout = true
          slow_callable = lambda { |_task|
            sleep(0.2)
            "slow result"
          }

          middleware.call(task, slow_callable)
          expect(task.result).to be_failed
        end

        it "skips timeout when condition is falsy" do
          task.should_timeout = false
          slow_callable = lambda { |_task|
            sleep(0.2)
            "slow result"
          }

          result = middleware.call(task, slow_callable)
          expect(result).to eq("slow result")
        end
      end

      context "with :unless condition" do
        let(:options) { { seconds: 0.05, unless: :skip_timeout? } }

        it "applies timeout when condition is falsy" do
          task.skip_timeout = false
          slow_callable = lambda { |_task|
            sleep(0.2)
            "slow result"
          }

          middleware.call(task, slow_callable)
          expect(task.result).to be_failed
        end

        it "skips timeout when condition is truthy" do
          task.skip_timeout = true
          slow_callable = lambda { |_task|
            sleep(0.2)
            "slow result"
          }

          result = middleware.call(task, slow_callable)
          expect(result).to eq("slow result")
        end
      end

      context "with both :if and :unless conditions" do
        let(:options) { { seconds: 0.05, if: :should_timeout?, unless: :skip_timeout? } }

        it "applies timeout when :if is truthy and :unless is falsy" do
          task.should_timeout = true
          task.skip_timeout = false
          slow_callable = lambda { |_task|
            sleep(0.2)
            "slow result"
          }

          middleware.call(task, slow_callable)
          expect(task.result).to be_failed
        end

        it "skips timeout when :unless is truthy regardless of :if" do
          task.should_timeout = true
          task.skip_timeout = true
          slow_callable = lambda { |_task|
            sleep(0.2)
            "slow result"
          }

          result = middleware.call(task, slow_callable)
          expect(result).to eq("slow result")
        end
      end
    end

    context "with dynamic timeout values" do
      let(:task_class) do
        create_simple_task do
          def timeout_value
            @timeout_value || 1
          end

          attr_writer :timeout_value
        end
      end

      context "with proc timeout" do
        let(:options) { { seconds: -> { 0.05 } } }

        it "evaluates proc to get timeout value" do
          slow_callable = lambda { |_task|
            sleep(0.2)
            "slow result"
          }

          middleware.call(task, slow_callable)
          expect(task.result).to be_failed
          expect(task.result.metadata[:seconds]).to eq(0.05)
        end
      end

      context "with symbol timeout" do
        let(:options) { { seconds: :timeout_value } }

        it "calls method to get timeout value" do
          task.timeout_value = 0.05
          slow_callable = lambda { |_task|
            sleep(0.2)
            "slow result"
          }

          middleware.call(task, slow_callable)
          expect(task.result).to be_failed
          expect(task.result.metadata[:seconds]).to eq(0.05)
        end
      end

      context "with nil timeout from evaluation" do
        let(:options) { { seconds: -> {} } }

        it "falls back to default timeout of 3 seconds" do
          slow_callable = lambda { |_task|
            sleep(0.1)
            "slow result"
          }

          # We need to temporarily override the default timeout to make the test run faster
          # and actually trigger the timeout. We'll mock the timeout call to simulate
          # what would happen with the default 3-second timeout.
          allow(Timeout).to receive(:timeout).with(3, CMDx::TimeoutError, "execution exceeded 3 seconds") do |_limit, exception_class, message|
            raise exception_class, message
          end

          middleware.call(task, slow_callable)
          expect(task.result).to be_failed
          expect(task.result.metadata[:seconds]).to eq(3)
        end
      end
    end

    context "with callable that raises other exceptions" do
      let(:options) { { seconds: 1 } }
      let(:error_callable) { ->(_task) { raise StandardError, "Something went wrong" } }

      it "allows other exceptions to propagate" do
        expect { middleware.call(task, error_callable) }.to raise_error(StandardError, "Something went wrong")
      end
    end
  end

  describe "integration with tasks" do
    let(:fast_task_class) do
      create_simple_task(name: "FastProcessingTask") do
        use :middleware, CMDx::Middlewares::Timeout, seconds: 1

        def call
          sleep(0.1)
          context.processed = true
          context.result = "completed quickly"
        end
      end
    end

    let(:slow_task_class) do
      create_simple_task(name: "SlowProcessingTask") do
        use :middleware, CMDx::Middlewares::Timeout, seconds: 0.05

        def call
          sleep(0.2)
          context.processed = true
          context.result = "should not reach here"
        end
      end
    end

    let(:conditional_task_class) do
      create_simple_task(name: "ConditionalTimeoutTask") do
        use :middleware, CMDx::Middlewares::Timeout, seconds: 0.05, if: :should_apply_timeout?

        optional :apply_timeout, type: :boolean, default: false

        def call
          sleep(0.1)
          context.processed = true
          context.result = "completed"
        end

        private

        def should_apply_timeout?
          apply_timeout
        end
      end
    end

    let(:dynamic_timeout_task_class) do
      create_simple_task(name: "DynamicTimeoutTask") do
        use :middleware, CMDx::Middlewares::Timeout, seconds: :timeout_duration

        required :timeout_duration, type: :float
        optional :work_time, type: :float, default: 0.1

        def call
          sleep(work_time)
          context.processed = true
          context.result = "work completed"
        end
      end
    end

    it "allows tasks to complete within timeout" do
      result = fast_task_class.call

      expect(result).to be_success
      expect(result.context.processed).to be(true)
      expect(result.context.result).to eq("completed quickly")
    end

    it "fails tasks that exceed timeout" do
      result = slow_task_class.call

      expect(result).to be_failed
      expect(result.metadata[:reason]).to match(/TimeoutError.*execution exceeded 0.05 seconds/)
      expect(result.metadata[:original_exception]).to be_a(CMDx::TimeoutError)
      expect(result.metadata[:seconds]).to eq(0.05)
      expect(result.context.processed).to be_nil
    end

    it "applies timeout conditionally based on task state" do
      result_without_timeout = conditional_task_class.call(apply_timeout: false)
      expect(result_without_timeout).to be_success
      expect(result_without_timeout.context.result).to eq("completed")

      result_with_timeout = conditional_task_class.call(apply_timeout: true)
      expect(result_with_timeout).to be_failed
      expect(result_with_timeout.metadata[:reason]).to match(/TimeoutError/)
    end

    it "uses dynamic timeout values from task parameters" do
      result_with_long_timeout = dynamic_timeout_task_class.call(timeout_duration: 1.0, work_time: 0.1)
      expect(result_with_long_timeout).to be_success
      expect(result_with_long_timeout.context.result).to eq("work completed")

      result_with_short_timeout = dynamic_timeout_task_class.call(timeout_duration: 0.05, work_time: 0.2)
      expect(result_with_short_timeout).to be_failed
      expect(result_with_short_timeout.metadata[:seconds]).to eq(0.05)
    end

    it "verifies middleware is properly registered on task class" do
      expect(fast_task_class.cmd_middlewares.registry).to have_key(CMDx::Middlewares::Timeout)
      expect(slow_task_class.cmd_middlewares.registry).to have_key(CMDx::Middlewares::Timeout)
      expect(conditional_task_class.cmd_middlewares.registry).to have_key(CMDx::Middlewares::Timeout)
      expect(dynamic_timeout_task_class.cmd_middlewares.registry).to have_key(CMDx::Middlewares::Timeout)
    end

    it "handles task exceptions that occur before timeout" do
      error_task_class = create_simple_task(name: "ErrorTask") do
        use :middleware, CMDx::Middlewares::Timeout, seconds: 1

        def call
          raise StandardError, "Task error occurred"
        end
      end

      expect { error_task_class.call! }.to raise_error(StandardError, "Task error occurred")
    end

    it "preserves task context when timeout occurs" do
      partial_work_task_class = create_simple_task(name: "PartialWorkTask") do
        use :middleware, CMDx::Middlewares::Timeout, seconds: 0.05

        def call
          context.step1_completed = true
          sleep(0.1)
          context.step2_completed = true
        end
      end

      result = partial_work_task_class.call

      expect(result).to be_failed
      expect(result.context.step1_completed).to be(true)
      expect(result.context.step2_completed).to be_nil
    end
  end
end
