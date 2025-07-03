# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task Middlewares Integration", type: :integration do
  # Helper method to capture middleware execution order
  let(:execution_log) { [] }

  # Clean up execution log before each test
  before { execution_log.clear }

  describe "Middleware Types and Usage Patterns" do
    context "with class middleware" do
      let(:timing_middleware) do
        Class.new(CMDx::Middleware) do
          def initialize(name, log)
            @name = name
            @log = log
          end

          def call(task, callable)
            @log << "#{@name}_before"
            result = callable.call(task)
            @log << "#{@name}_after"
            result
          end
        end
      end

      let(:test_task) do
        middleware_class = timing_middleware
        log = execution_log
        Class.new(CMDx::Task) do
          use middleware_class, "timing", log

          define_method :call do
            log << "task_execution"
            context.result = "success"
          end
        end
      end

      it "executes class middleware with initialization arguments" do
        result = test_task.call

        expect(result).to be_successful_task
        expect(execution_log).to eq(%w[timing_before task_execution timing_after])
        expect(result.context.result).to eq("success")
      end
    end

    context "with instance middleware" do
      let(:validation_middleware) do
        Class.new(CMDx::Middleware) do
          def initialize(log:, required_field: nil)
            @required_field = required_field
            @log = log
          end

          def call(task, callable)
            @log << "validation_before"

            if @required_field && !task.context.respond_to?(@required_field)
              task.result.fail!(
                reason: "Missing required field: #{@required_field}",
                original_exception: StandardError.new("Validation failed")
              )
              return task.result
            end

            result = callable.call(task)
            @log << "validation_after"
            result
          end
        end
      end

      let(:test_task) do
        middleware_instance = validation_middleware.new(log: execution_log, required_field: :user_id)
        log = execution_log
        Class.new(CMDx::Task) do
          use middleware_instance

          define_method :call do
            log << "task_execution"
            context.processed = true
          end
        end
      end

      it "executes instance middleware with pre-configured settings" do
        result = test_task.call(user_id: 123)

        expect(result).to be_successful_task
        expect(execution_log).to eq(%w[validation_before task_execution validation_after])
        expect(result.context.processed).to be(true)
      end

      it "fails when required field is missing" do
        result = test_task.call(name: "test")

        expect(result).to be_failed
        expect(result).to have_metadata(reason: "Missing required field: user_id")
        expect(execution_log).to eq(["validation_before"])
      end
    end

    context "with proc middleware" do
      let(:test_task) do
        log = execution_log
        Class.new(CMDx::Task) do
          use proc { |task, callable|
            log << "proc_before"
            result = callable.call(task)
            log << "proc_after"
            result
          }

          define_method :call do
            log << "task_execution"
            context.inline_result = "processed"
          end
        end
      end

      it "executes proc middleware for inline functionality" do
        result = test_task.call

        expect(result).to be_successful_task
        expect(execution_log).to eq(%w[proc_before task_execution proc_after])
        expect(result.context.inline_result).to eq("processed")
      end
    end
  end

  describe "Middleware Execution Order" do
    context "with nested middleware chain" do
      let(:timing_middleware) do
        log = execution_log
        Class.new(CMDx::Middleware) do
          define_method :call do |task, callable|
            log << "timing_before"
            start_time = Time.now
            result = callable.call(task)
            log << "timing_after"
            task.context.duration = Time.now - start_time
            result
          end
        end
      end

      let(:auth_middleware) do
        log = execution_log
        Class.new(CMDx::Middleware) do
          define_method :call do |task, callable|
            log << "auth_before"
            task.context.user = "authenticated_user"
            result = callable.call(task)
            log << "auth_after"
            result
          end
        end
      end

      let(:validation_middleware) do
        log = execution_log
        Class.new(CMDx::Middleware) do
          define_method :call do |task, callable|
            log << "validation_before"
            result = callable.call(task)
            log << "validation_after"
            result
          end
        end
      end

      let(:test_task) do
        timing_mw = timing_middleware.new
        auth_mw = auth_middleware.new
        validation_mw = validation_middleware.new
        log = execution_log
        Class.new(CMDx::Task) do
          use timing_mw
          use auth_mw
          use validation_mw

          define_method :call do
            log << "task_execution"
            context.order_processed = true
          end
        end
      end

      it "executes middleware in nested order with proper before/after sequencing" do
        result = test_task.call

        expect(result).to be_successful_task
        expect(execution_log).to eq(%w[
                                      timing_before
                                      auth_before
                                      validation_before
                                      task_execution
                                      validation_after
                                      auth_after
                                      timing_after
                                    ])
        expect(result.context.user).to eq("authenticated_user")
        expect(result.context.order_processed).to be(true)
        expect(result.context.duration).to be_a(Numeric)
      end
    end
  end

  describe "Middleware Short-circuiting" do
    context "with rate limiting middleware" do
      let(:request_counter) { { count: 0 } }

      let(:rate_limit_middleware) do
        Class.new(CMDx::Middleware) do
          def initialize(log:, counter:)
            @counter = counter
            @limit = 3
            @log = log
          end

          def call(task, callable)
            @counter[:count] += 1
            @log << "rate_limit_check"

            if @counter[:count] > @limit
              @log << "rate_limit_exceeded"
              task.result.fail!(
                reason: "Rate limit exceeded",
                attempts: @counter[:count],
                original_exception: StandardError.new("Rate limit exceeded")
              )
              return task.result
            end

            @log << "rate_limit_passed"
            result = callable.call(task)
            @log << "rate_limit_after"
            result
          end
        end
      end

      let(:test_task) do
        rate_limiter = rate_limit_middleware.new(log: execution_log, counter: request_counter)
        log = execution_log
        Class.new(CMDx::Task) do
          use rate_limiter

          define_method :call do
            log << "task_execution"
            context.request_processed = true
          end
        end
      end

      it "allows execution when under rate limit" do
        # First 3 requests should pass
        3.times do |_i|
          execution_log.clear
          result = test_task.call

          expect(result).to be_successful_task
          expect(execution_log).to include("rate_limit_check", "rate_limit_passed", "task_execution", "rate_limit_after")
          expect(result.context.request_processed).to be(true)
        end
      end

      it "short-circuits execution when rate limit exceeded" do
        # Reset counter for this test
        request_counter[:count] = 0

        # Exceed the rate limit (make 4 requests)
        3.times { test_task.call }
        execution_log.clear

        result = test_task.call

        expect(result).to be_failed
        expect(result).to have_metadata(reason: "Rate limit exceeded")
        expect(result.metadata[:attempts]).to eq(4)
        expect(execution_log).to eq(%w[rate_limit_check rate_limit_exceeded])
        expect(execution_log).not_to include("task_execution")
      end
    end
  end

  describe "Middleware Inheritance" do
    context "with application-level and task-specific middleware" do
      let(:app_logging_middleware) do
        log = execution_log
        Class.new(CMDx::Middleware) do
          define_method :call do |task, callable|
            log << "app_logging_before"
            result = callable.call(task)
            log << "app_logging_after"
            result
          end
        end
      end

      let(:base_task) do
        app_middleware = app_logging_middleware.new
        Class.new(CMDx::Task) do
          use app_middleware
        end
      end

      let(:specific_middleware) do
        log = execution_log
        Class.new(CMDx::Middleware) do
          define_method :call do |task, callable|
            log << "specific_before"
            result = callable.call(task)
            log << "specific_after"
            result
          end
        end
      end

      let(:child_task) do
        specific_mw = specific_middleware.new
        log = execution_log
        Class.new(base_task) do
          use specific_mw

          define_method :call do
            log << "child_task_execution"
            context.child_processed = true
          end
        end
      end

      it "inherits middleware from parent class and executes in proper order" do
        result = child_task.call

        expect(result).to be_successful_task
        expect(execution_log).to eq(%w[
                                      app_logging_before
                                      specific_before
                                      child_task_execution
                                      specific_after
                                      app_logging_after
                                    ])
        expect(result.context.child_processed).to be(true)
      end
    end
  end

  describe "Built-in Timeout Middleware" do
    context "with static timeout value" do
      let(:test_task) do
        log = execution_log
        Class.new(CMDx::Task) do
          use CMDx::Middlewares::Timeout, seconds: 0.1

          define_method :call do
            log << "task_start"
            sleep(0.2) # Exceed timeout
            log << "task_end"
            context.completed = true
          end
        end
      end

      it "enforces timeout and fails task when exceeded" do
        result = test_task.call

        expect(result).to be_failed
        expect(result).to have_metadata(reason: match(/execution exceeded.*seconds/i))
        expect(execution_log).to eq(["task_start"])
        expect(execution_log).not_to include("task_end")
      end
    end

    context "with dynamic timeout calculation" do
      let(:test_task) do
        log = execution_log
        Class.new(CMDx::Task) do
          use CMDx::Middlewares::Timeout, seconds: :calculate_timeout

          define_method :calculate_timeout do
            context.workflow_size ? context.workflow_size * 0.05 : 0.1
          end

          define_method :call do
            log << "task_execution"
            context.items_processed = context.workflow_size || 1
          end
        end
      end

      it "calculates timeout dynamically based on task context" do
        result = test_task.call(workflow_size: 10)

        expect(result).to be_successful_task
        expect(execution_log).to eq(["task_execution"])
        expect(result.context.items_processed).to eq(10)
      end
    end

    context "with proc-based timeout" do
      let(:test_task) do
        log = execution_log
        Class.new(CMDx::Task) do
          use CMDx::Middlewares::Timeout, seconds: :calculate_timeout

          define_method :calculate_timeout do
            context.workflow_size ? context.workflow_size * 0.05 : 0.1
          end

          define_method :call do
            log << "task_execution"
            context.processed = true
          end
        end
      end

      it "uses proc to determine timeout value" do
        result = test_task.call(workflow_size: 5)

        expect(result).to be_successful_task
        expect(execution_log).to eq(["task_execution"])
        expect(result.context.processed).to be(true)
      end
    end
  end

  describe "Built-in Correlate Middleware" do
    context "with explicit correlation ID" do
      let(:captured_correlation_id) { [] }

      let(:test_task) do
        log = execution_log
        correlation_capture = captured_correlation_id
        Class.new(CMDx::Task) do
          use CMDx::Middlewares::Correlate, id: "correlation-123"

          define_method :call do
            log << "task_execution"
            correlation_capture << CMDx::Correlator.id
            context.work_completed = true
          end
        end
      end

      it "sets correlation ID during task execution" do
        result = test_task.call

        expect(result).to be_successful_task
        expect(captured_correlation_id.last).to eq("correlation-123")
        expect(result.context.work_completed).to be(true)
      end
    end

    context "with dynamic correlation ID using proc" do
      let(:captured_correlation_id) { [] }

      let(:test_task) do
        log = execution_log
        correlation_capture = captured_correlation_id
        Class.new(CMDx::Task) do
          use CMDx::Middlewares::Correlate, id: :generate_correlation_id

          define_method :generate_correlation_id do
            "req-#{context.request_id}-#{Time.now.to_i}"
          end

          define_method :call do
            log << "task_execution"
            correlation_capture << CMDx::Correlator.id
            context.processed = true
          end
        end
      end

      it "generates correlation ID dynamically using method" do
        result = test_task.call(request_id: "abc123")

        expect(result).to be_successful_task
        expect(captured_correlation_id.last).to match(/^req-abc123-\d+$/)
        expect(result.context.processed).to be(true)
      end
    end

    context "with method-based correlation ID" do
      let(:captured_correlation_id) { [] }

      let(:test_task) do
        log = execution_log
        correlation_capture = captured_correlation_id
        Class.new(CMDx::Task) do
          use CMDx::Middlewares::Correlate, id: :build_correlation_id

          define_method :build_correlation_id do
            "method-generated-#{context.session_id}"
          end

          define_method :call do
            log << "task_execution"
            correlation_capture << CMDx::Correlator.id
            context.session_processed = true
          end
        end
      end

      it "generates correlation ID using method" do
        result = test_task.call(session_id: "sess_456")

        expect(result).to be_successful_task
        expect(captured_correlation_id.last).to eq("method-generated-sess_456")
        expect(result.context.session_processed).to be(true)
      end
    end
  end

  describe "Custom Middleware Development" do
    context "with database transaction middleware" do
      let(:transaction_middleware) do
        log = execution_log
        Class.new(CMDx::Middleware) do
          define_method :call do |task, callable|
            log << "transaction_begin"

            begin
              result = callable.call(task)

              # Check if the task failed by examining the result object
              if task.result.failed?
                log << "transaction_rollback"
                task.context.transaction_rolled_back = true
              else
                log << "transaction_commit"
                task.context.transaction_committed = true
              end

              result
            rescue StandardError => e
              log << "transaction_rollback_error"
              task.context.transaction_rolled_back = true
              task.result.fail!(reason: "Transaction failed", error: e.message, original_exception: e)
              task.result
            end
          end
        end
      end

      let(:successful_task) do
        tx_middleware = transaction_middleware.new
        log = execution_log
        Class.new(CMDx::Task) do
          use tx_middleware

          define_method :call do
            log << "task_execution"
            context.data_saved = true
          end
        end
      end

      let(:failing_task) do
        tx_middleware = transaction_middleware.new
        log = execution_log
        Class.new(CMDx::Task) do
          use tx_middleware

          define_method :call do
            log << "task_execution"
            fail!(reason: "Business logic error")
          end
        end
      end

      it "commits transaction on successful task execution" do
        result = successful_task.call

        expect(result).to be_successful_task
        expect(execution_log).to eq(%w[transaction_begin task_execution transaction_commit])
        expect(result.context.transaction_committed).to be(true)
        expect(result.context.data_saved).to be(true)
      end

      it "rolls back transaction on failed task execution" do
        result = failing_task.call

        expect(result).to be_failed_task
        expect(result.metadata[:reason]).to eq("Business logic error")
        expect(execution_log).to eq(%w[transaction_begin task_execution transaction_rollback])
        expect(result.context.transaction_rolled_back).to be(true)
      end
    end

    context "with circuit breaker middleware" do
      let(:circuit_breaker_middleware) do
        Class.new(CMDx::Middleware) do
          def initialize(log:, failure_threshold: 3)
            @failure_count = 0
            @failure_threshold = failure_threshold
            @circuit_open = false
            @log = log
          end

          def call(task, callable)
            @log << "circuit_check"

            if @circuit_open
              @log << "circuit_open"
              task.result.fail!(
                reason: "Circuit breaker is open",
                failures: @failure_count,
                original_exception: StandardError.new("Circuit breaker is open")
              )
              return task.result
            end

            @log << "circuit_closed"

            begin
              result = callable.call(task)

              # Check if the task failed by examining the task's result object
              if task.result.failed?
                @failure_count += 1
                if @failure_count >= @failure_threshold
                  @circuit_open = true
                  @log << "circuit_opened"
                end
              else
                @failure_count = 0
                @log << "circuit_reset"
              end

              result
            end
          end
        end
      end

      let(:test_task) do
        circuit_breaker = circuit_breaker_middleware.new(log: execution_log, failure_threshold: 2)
        log = execution_log
        Class.new(CMDx::Task) do
          use circuit_breaker

          define_method :call do
            log << "task_execution"
            if context.should_fail
              fail!(reason: "Simulated failure")
            else
              context.success = true
            end
          end
        end
      end

      it "allows execution when circuit is closed" do
        result = test_task.call(should_fail: false)

        expect(result).to be_successful_task
        expect(execution_log).to include("circuit_check", "circuit_closed", "task_execution", "circuit_reset")
        expect(result.context.success).to be(true)
      end

      it "opens circuit after threshold failures and blocks subsequent requests" do
        # Cause 2 failures to open circuit
        2.times do
          execution_log.clear
          result = test_task.call(should_fail: true)
          expect(result).to be_failed_task
        end

        expect(execution_log).to include("circuit_opened")

        # Next request should be blocked
        execution_log.clear

        # Wrap the call in begin/rescue to handle the CMDx::Failed exception
        begin
          result = test_task.call(should_fail: false)
          expect(result).to be_failed
          expect(result).to have_metadata(reason: "Circuit breaker is open", failures: 2)
        rescue CMDx::Failed => e
          # The circuit breaker is short-circuiting by raising an exception
          expect(e.result).to have_metadata(reason: "Circuit breaker is open", failures: 2)
        end

        expect(execution_log).to eq(%w[circuit_check circuit_open])
        expect(execution_log).not_to include("task_execution")
      end
    end
  end

  describe "Complex Middleware Scenarios" do
    context "with e-commerce order processing workflow" do
      let(:request_counter) { { count: 0 } }

      let(:auth_middleware) do
        Class.new(CMDx::Middleware) do
          def initialize(log:)
            @log = log
          end

          def call(task, callable)
            @log << "auth_check"
            unless task.context.user_token
              task.result.fail!(
                reason: "Authentication required",
                original_exception: StandardError.new("Authentication required")
              )
              return task.result
            end
            task.context.authenticated_user = "user_#{task.context.user_token}"
            result = callable.call(task)
            @log << "auth_complete"
            result
          end
        end
      end

      let(:rate_limit_middleware) do
        Class.new(CMDx::Middleware) do
          def initialize(log:, counter:)
            @counter = counter
            @log = log
          end

          def call(task, callable)
            @log << "rate_limit_check"
            @counter[:count] += 1
            if @counter[:count] > 5
              task.result.fail!(
                reason: "Rate limit exceeded",
                original_exception: StandardError.new("Rate limit exceeded")
              )
              return task.result
            end
            result = callable.call(task)
            @log << "rate_limit_passed"
            result
          end
        end
      end

      let(:performance_middleware) do
        Class.new(CMDx::Middleware) do
          def initialize(log:)
            @log = log
          end

          def call(task, callable)
            @log << "performance_start"
            start_time = Time.now
            result = callable.call(task)
            duration = Time.now - start_time
            task.context.processing_time = duration
            @log << "performance_end"
            result
          end
        end
      end

      let(:cleanup_middleware) do
        Class.new(CMDx::Middleware) do
          def initialize(log:)
            @log = log
          end

          def call(task, callable)
            @log << "cleanup_before"
            result = callable.call(task)
            task.context.cleanup_performed = true
            @log << "cleanup_after"
            result
          end
        end
      end

      let(:order_task) do
        auth_mw = auth_middleware.new(log: execution_log)
        rate_mw = rate_limit_middleware.new(log: execution_log, counter: request_counter)
        perf_mw = performance_middleware.new(log: execution_log)
        cleanup_mw = cleanup_middleware.new(log: execution_log)
        log = execution_log

        Class.new(CMDx::Task) do
          use auth_mw
          use rate_mw
          use perf_mw
          use cleanup_mw

          define_method :call do
            log << "order_processing"
            context.order_id = "ord_#{rand(1000)}"
            context.order_total = context.amount * 1.08 # Add tax
            context.order_status = "completed"
          end
        end
      end

      before do
        request_counter[:count] = 0
      end

      it "processes order successfully with full middleware chain" do
        result = order_task.call(user_token: "abc123", amount: 100.0)

        expect(result).to be_successful_task
        expect(execution_log).to eq(%w[
                                      auth_check
                                      rate_limit_check
                                      performance_start
                                      cleanup_before
                                      order_processing
                                      cleanup_after
                                      performance_end
                                      rate_limit_passed
                                      auth_complete
                                    ])

        expect(result.context.authenticated_user).to eq("user_abc123")
        expect(result.context.order_total).to eq(108.0)
        expect(result.context.order_status).to eq("completed")
        expect(result.context.processing_time).to be_a(Numeric)
        expect(result.context.cleanup_performed).to be(true)
      end

      it "fails early when authentication is missing" do
        result = order_task.call(amount: 100.0)

        expect(result).to be_failed
        expect(result).to have_metadata(reason: "Authentication required")
        expect(execution_log).to eq(["auth_check"])
      end
    end
  end
end
