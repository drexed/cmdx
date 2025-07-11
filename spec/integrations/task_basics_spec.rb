# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task Basics", type: :integration do
  describe "Basic Task Structure and Execution" do
    let(:simple_task) do
      Class.new(CMDx::Task) do
        def call
          context.executed = true
          context.execution_time = Time.now
        end
      end
    end

    let(:parameterized_task) do
      Class.new(CMDx::Task) do
        required :user_id, type: :integer
        optional :notify_user, type: :boolean, default: true

        def call
          context.user = { id: user_id, name: "User #{user_id}" }
          context.notification_sent = notify_user
        end
      end
    end

    context "when executing basic tasks" do
      it "executes task with call method" do
        result = simple_task.call

        expect(result).to be_successful_task
        expect(result).to have_context(executed: true, execution_time: be_a(Time))
      end

      it "maintains task lifecycle states" do
        result = simple_task.call

        expect(result).to be_successful_task
        expect(result).to have_runtime(be >= 0)
      end

      it "prevents multiple executions" do
        instance = simple_task.new
        instance.process

        expect(instance.result.state).to eq("complete")
        expect { instance.process }.to raise_error(RuntimeError, /cannot transition/)
      end
    end

    context "with parameter validation" do
      it "validates required parameters" do
        result = parameterized_task.call(user_id: 123)

        expect(result).to be_successful_task(user_id: 123)
        expect(result).to have_context(
          user: { id: 123, name: "User 123" },
          notification_sent: true
        )
      end

      it "uses optional parameter defaults" do
        result = parameterized_task.call(user_id: 456, notify_user: false)

        expect(result).to be_successful_task(user_id: 456, notify_user: false)
        expect(result).to have_context(notification_sent: false)
      end
    end

    context "with inheritance patterns" do
      let(:application_task) do
        Class.new(CMDx::Task) do
          def self.name
            "ApplicationTask"
          end

          before_execution :setup_common_context
          after_execution :cleanup_resources

          private

          def setup_common_context
            context.app_name = "MyApp"
            context.execution_started_at = Time.now
          end

          def cleanup_resources
            context.cleanup_performed = true
          end
        end
      end

      let(:inherited_task) do
        app_task = application_task
        Class.new(app_task) do
          def call
            context.specific_work_done = true
          end
        end
      end

      it "inherits functionality from parent class" do
        result = inherited_task.call

        expect(result).to be_successful_task
        expect(result).to have_context(
          app_name: "MyApp",
          execution_started_at: be_a(Time),
          specific_work_done: true,
          cleanup_performed: true
        )
      end
    end

    context "with result object context passing" do
      let(:data_extraction_task) do
        Class.new(CMDx::Task) do
          def call
            context.extracted_data = {
              source_id: context.source_id || 123,
              format: context.format || "json",
              extracted_at: Time.now
            }
          end
        end
      end

      let(:data_processing_task) do
        Class.new(CMDx::Task) do
          def call
            fail!(reason: "No extracted data found") unless context.extracted_data

            context.processed_data = {
              original: context.extracted_data,
              processed_at: Time.now,
              status: "completed"
            }
          end
        end
      end

      it "passes result context between tasks" do
        # First task extracts data
        extraction_result = data_extraction_task.call(source_id: 123, format: "xml")
        expect(extraction_result).to be_successful_task

        # Second task processes the data using the first task's result
        processing_result = data_processing_task.call(extraction_result)
        expect(processing_result).to be_successful_task

        # Verify the context was properly passed
        expect(processing_result.context.extracted_data[:source_id]).to eq(123)
        expect(processing_result.context.extracted_data[:format]).to eq("xml")
        expect(processing_result.context.processed_data[:status]).to eq("completed")
      end

      it "preserves all context data when using result object" do
        # Add custom context data
        extraction_result = data_extraction_task.call(source_id: 456, format: "csv")
        extraction_result.context.custom_metadata = { version: "1.0", author: "test" }

        # Pass result to new task
        processing_result = data_processing_task.call(extraction_result)

        # Verify custom metadata is preserved
        expect(processing_result.context.custom_metadata).to eq({ version: "1.0", author: "test" })
        expect(processing_result.context.source_id).to eq(456)
        expect(processing_result.context.format).to eq("csv")
      end
    end
  end

  describe "Call Methods and Error Handling" do
    let(:successful_task) do
      Class.new(CMDx::Task) do
        def call
          context.operation_result = "success"
        end
      end
    end

    let(:failing_task) do
      Class.new(CMDx::Task) do
        def call
          fail!(reason: "Something went wrong", error_code: "ERR001")
        end
      end
    end

    let(:skipping_task) do
      Class.new(CMDx::Task) do
        def call
          skip!(reason: "Conditions not met", condition: "user_inactive")
        end
      end
    end

    context "when using non-bang call method" do
      it "returns result for successful execution" do
        result = successful_task.call

        expect(result).to be_successful_task
        expect(result).to have_context(operation_result: "success")
      end

      it "returns result for failed execution" do
        result = failing_task.call

        expect(result).to be_failed_task
        expect(result).to have_metadata(reason: "Something went wrong", error_code: "ERR001")
      end

      it "returns result for skipped execution" do
        result = skipping_task.call

        expect(result).to be_skipped_task
        expect(result).to have_metadata(reason: "Conditions not met", condition: "user_inactive")
      end
    end

    context "when using bang call method" do
      it "returns result for successful execution" do
        result = successful_task.call!

        expect(result).to be_successful_task
        expect(result).to have_context(operation_result: "success")
      end

      it "raises exception for failed execution" do
        expect { failing_task.call! }.to raise_error(CMDx::Failed) do |error|
          expect(error.result).to be_failed_task
          expect(error.result).to have_metadata(reason: "Something went wrong")
        end
      end

      it "raises exception for skipped execution when configured" do
        # Configure task to halt on skip
        skip_task = Class.new(CMDx::Task) do
          cmd_settings! task_halt: %w[failed skipped]

          def call
            skip!(reason: "Conditions not met", condition: "user_inactive")
          end
        end

        expect { skip_task.call! }.to raise_error(CMDx::Skipped) do |error|
          expect(error.result).to be_skipped_task
          expect(error.result).to have_metadata(reason: "Conditions not met")
        end
      end
    end

    context "with direct instantiation" do
      it "allows manual execution control" do
        task = successful_task.new(test_param: "value")

        expect(task.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
        expect(task.context.test_param).to eq("value")
        expect(task.result.state).to eq("initialized")

        task.process

        expect(task.result.state).to eq("complete")
        expect(task.result).to be_success
        expect(task.context.operation_result).to eq("success")
      end
    end

    context "with result propagation" do
      let(:subtask_failing_task) do
        Class.new(CMDx::Task) do
          def call
            fail!(reason: "Subtask failed")
          end
        end
      end

      let(:parent_task) do
        failing_subtask = subtask_failing_task
        Class.new(CMDx::Task) do
          define_method :call do
            subtask_result = failing_subtask.call(context)
            throw!(subtask_result) if subtask_result.failed?

            context.parent_work_done = true
          end
        end
      end

      it "propagates failure from subtask" do
        result = parent_task.call

        expect(result).to be_failed_task
        expect(result.metadata[:reason]).to eq("Subtask failed")
        expect(result.context.parent_work_done).to be_nil
      end
    end
  end

  describe "Context Data Management" do
    let(:context_reader_task) do
      Class.new(CMDx::Task) do
        def call
          # Method-style access
          context.processed_user_id = context.user_id
          context.processed_order_id = context.order_id

          # Hash-style access
          context.processed_metadata = context[:metadata]

          # Safe access with defaults
          context.priority = context.fetch!(:priority, "normal")

          # Deep access for nested data
          context.source = context.dig(:settings, :source)
        end
      end
    end

    let(:context_modifier_task) do
      Class.new(CMDx::Task) do
        def call
          # Direct assignment
          context.user = { id: context.user_id, name: "User #{context.user_id}" }
          context.processed_at = Time.now

          # Hash-style assignment
          context[:status] = "processing"
          context["result_code"] = "SUCCESS"

          # Conditional assignment
          context.notification_sent ||= false

          # Workflow updates
          context.merge!(
            status: "completed",
            completion_time: Time.now
          )
        end
      end
    end

    context "when loading and accessing parameters" do
      it "loads and accesses various parameter types" do
        result = context_reader_task.call(
          user_id: 123,
          order_id: 456,
          metadata: { type: "order", version: 2 },
          settings: { source: "api", debug: true }
        )

        expect(result).to be_successful_task
        expect(result.context.processed_user_id).to eq(123)
        expect(result.context.processed_order_id).to eq(456)
        expect(result.context.processed_metadata).to eq({ type: "order", version: 2 })
        expect(result.context.priority).to eq("normal")
        expect(result.context.source).to eq("api")
      end

      it "handles nil values gracefully" do
        result = context_reader_task.call(user_id: 123)

        expect(result).to be_successful_task
        expect(result.context.processed_user_id).to eq(123)
        expect(result.context.processed_order_id).to be_nil
        expect(result.context.processed_metadata).to be_nil
        expect(result.context.priority).to eq("normal")
        expect(result.context.source).to be_nil
      end
    end

    context "when modifying context during execution" do
      it "supports various modification patterns" do
        result = context_modifier_task.call(user_id: 789)

        expect(result).to be_successful_task
        expect(result.context.user).to eq({ id: 789, name: "User 789" })
        expect(result.context.processed_at).to be_a(Time)
        expect(result.context.status).to eq("completed")
        expect(result.context.result_code).to eq("SUCCESS")
        expect(result.context.notification_sent).to be(false)
        expect(result.context.completion_time).to be_a(Time)
      end
    end

    context "with context sharing between tasks" do
      let(:data_loader_task) do
        Class.new(CMDx::Task) do
          def call
            context.user = { id: context.user_id, email: "user#{context.user_id}@example.com" }
            context.loaded_at = Time.now
          end
        end
      end

      let(:data_processor_task) do
        Class.new(CMDx::Task) do
          def call
            return fail!(reason: "No user data") unless context.user

            context.processed_user = context.user.merge(processed: true)
            context.processing_duration = Time.now - context.loaded_at
          end
        end
      end

      it "shares context data between tasks" do
        # First task loads data
        load_result = data_loader_task.call(user_id: 555)

        expect(load_result).to be_success
        expect(load_result.context.user[:id]).to eq(555)
        expect(load_result.context.loaded_at).to be_a(Time)

        # Second task processes shared context
        process_result = data_processor_task.call(load_result.context)

        expect(process_result).to be_success
        expect(process_result.context.processed_user[:id]).to eq(555)
        expect(process_result.context.processed_user[:processed]).to be(true)
        expect(process_result.context.processing_duration).to be > 0
      end
    end

    context "with context inspection and conversion" do
      it "provides inspection methods" do
        result = context_modifier_task.call(user_id: 999)

        context_hash = result.context.to_h

        expect(context_hash).to include(
          user_id: 999,
          status: "completed",
          result_code: "SUCCESS"
        )
        expect(context_hash[:user]).to eq({ id: 999, name: "User 999" })
        expect(result.context.inspect).to include("CMDx::Context")
      end
    end
  end

  describe "Chain Management and Correlation" do
    let(:chain_aware_task) do
      Class.new(CMDx::Task) do
        def call
          context.chain_id = chain.id
          context.task_index = chain.index(result)
          context.chain_size = chain.results.size
        end
      end
    end

    let(:subtask_caller_task) do
      aware_task = chain_aware_task
      Class.new(CMDx::Task) do
        define_method :call do
          context.main_task_executed = true

          # Call subtasks that inherit the same chain
          aware_task.call(context)
          aware_task.call(context)
        end
      end
    end

    context "with automatic chain creation" do
      it "creates chain for single task execution" do
        result = chain_aware_task.call

        expect(result).to be_successful_task
        expect(result.chain).to be_a(CMDx::Chain)
        expect(result.chain.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
        expect(result.chain.results.size).to eq(1)
        expect(result.context.chain_id).to eq(result.chain.id)
        expect(result.context.task_index).to eq(0)
      end
    end

    context "with chain inheritance" do
      it "maintains chain across subtask calls" do
        result = subtask_caller_task.call

        expect(result).to be_successful_task
        expect(result.chain.results.size).to be >= 1

        # Chain maintains shared ID across results
        expect(result.chain.id).to be_a(String)
        expect(result.context.main_task_executed).to be(true)
      end
    end

    context "with custom correlation IDs" do
      it "uses custom chain ID when provided" do
        custom_chain = CMDx::Chain.new(id: "custom-correlation-123")
        CMDx::Chain.current = custom_chain

        result = chain_aware_task.call

        expect(result.chain.id).to eq("custom-correlation-123")
        expect(result.context.chain_id).to eq("custom-correlation-123")

        CMDx::Chain.clear
      end

      it "inherits thread-local correlation ID" do
        CMDx::Correlator.id = "thread-correlation-456"

        result = chain_aware_task.call

        expect(result.chain.id).to eq("thread-correlation-456")
        expect(result.context.chain_id).to eq("thread-correlation-456")

        CMDx::Correlator.clear
      end
    end

    context "with chain state delegation" do
      let(:mixed_outcome_task) do
        Class.new(CMDx::Task) do
          def call
            context.first_executed = true
          end
        end
      end

      let(:failing_subtask) do
        Class.new(CMDx::Task) do
          def call
            fail!(reason: "Subtask failure")
          end
        end
      end

      it "delegates chain state from first result" do
        # Execute successful task first
        first_result = mixed_outcome_task.call

        expect(first_result.chain.state).to eq("complete")
        expect(first_result.chain.status).to eq("success")

        # Execute failing task in same chain
        second_result = failing_subtask.call

        expect(second_result.chain.state).to eq("complete") # From first result
        expect(second_result.chain.status).to eq("success") # From first result
        expect(second_result.chain.results.size).to eq(2)

        CMDx::Chain.clear
      end
    end

    context "with chain serialization" do
      it "provides comprehensive chain metadata" do
        result = subtask_caller_task.call

        chain_data = result.chain.to_h

        expect(chain_data).to include(:id, :state, :status, :outcome, :runtime, :results)
        expect(chain_data[:results]).to be_an(Array)
        expect(chain_data[:results].size).to be >= 1
        expect(chain_data[:id]).to eq(result.chain.id)

        CMDx::Chain.clear
      end
    end
  end

  describe "Result Callbacks and Fluent Interface" do
    let(:callback_test_task) do
      Class.new(CMDx::Task) do
        def call
          context.operation_completed = true
        end
      end
    end

    let(:failing_callback_task) do
      Class.new(CMDx::Task) do
        def call
          fail!(reason: "Intentional failure", code: 500)
        end
      end
    end

    context "with successful task callbacks" do
      it "executes success callbacks" do
        success_called = false
        complete_called = false
        executed_called = false

        result = callback_test_task.call
                                   .on_success { |_r| success_called = true }
                                   .on_complete { |_r| complete_called = true }
                                   .on_executed { |_r| executed_called = true }
                                   .on_failed { |_r| raise "Should not be called" }

        expect(result).to be_successful_task
        expect(success_called).to be(true)
        expect(complete_called).to be(true)
        expect(executed_called).to be(true)
      end

      it "provides result data in callbacks" do
        callback_context = nil
        callback_runtime = nil

        callback_test_task.call
                          .on_success do |r|
          callback_context = r.context
          callback_runtime = r.runtime
        end

        expect(callback_context.operation_completed).to be(true)
        expect(callback_runtime).to be >= 0
      end
    end

    context "with failed task callbacks" do
      it "executes failure callbacks" do
        failed_called = false
        interrupted_called = false
        executed_called = false

        result = failing_callback_task.call
                                      .on_failed { |_r| failed_called = true }
                                      .on_interrupted { |_r| interrupted_called = true }
                                      .on_executed { |_r| executed_called = true }
                                      .on_success { |_r| raise "Should not be called" }

        expect(result).to be_failed_task
        expect(failed_called).to be(true)
        expect(interrupted_called).to be(true)
        expect(executed_called).to be(true)
      end

      it "provides failure metadata in callbacks" do
        failure_reason = nil
        failure_code = nil

        failing_callback_task.call
                             .on_failed do |r|
          failure_reason = r.metadata[:reason]
          failure_code = r.metadata[:code]
        end

        expect(failure_reason).to eq("Intentional failure")
        expect(failure_code).to eq(500)
      end
    end

    context "with outcome-based callbacks" do
      it "calls good callbacks for success" do
        good_called = false
        bad_called = false

        callback_test_task.call
                          .on_good { |_r| good_called = true }
                          .on_bad { |_r| bad_called = true }

        expect(good_called).to be(true)
        expect(bad_called).to be(false)
      end

      it "calls bad callbacks for failure" do
        good_called = false
        bad_called = false

        failing_callback_task.call
                             .on_good { |_r| good_called = true }
                             .on_bad { |_r| bad_called = true }

        expect(good_called).to be(false)
        expect(bad_called).to be(true)
      end
    end

    context "with method chaining" do
      it "maintains fluent interface" do
        execution_log = []

        result = callback_test_task.call
                                   .on_executed { |_r| execution_log << "executed" }
                                   .on_success { |_r| execution_log << "success" }
                                   .on_complete { |_r| execution_log << "complete" }
                                   .on_good { |_r| execution_log << "good" }

        expect(result).to be_successful_task
        expect(execution_log).to eq(%w[executed success complete good])
      end
    end
  end

  describe "Complex Integration Scenarios" do
    let(:user_registration_task) do
      Class.new(CMDx::Task) do
        required :email, type: :string
        required :name, type: :string
        optional :send_welcome, type: :boolean, default: true

        def call
          return fail!(reason: "Invalid email") unless email.include?("@")

          context.user = {
            id: rand(1000..9999),
            email: email,
            name: name,
            created_at: Time.now
          }
        end
      end
    end

    let(:welcome_email_task) do
      Class.new(CMDx::Task) do
        def call
          return skip!(reason: "No user to email") unless context.user
          return skip!(reason: "Welcome email disabled") unless context.send_welcome

          context.email_sent = true
          context.email_id = "email_#{context.user[:id]}"
        end
      end
    end

    let(:audit_log_task) do
      Class.new(CMDx::Task) do
        def call
          context.audit_entry = {
            action: "user_registration",
            user_id: context.user&.dig(:id),
            timestamp: Time.now,
            success: context.user ? true : false
          }
        end
      end
    end

    context "with successful workflow" do
      it "executes complete user registration workflow" do
        # Register user
        registration_result = user_registration_task.call(
          email: "test@example.com",
          name: "Test User",
          send_welcome: true
        )

        expect(registration_result).to be_success
        expect(registration_result.context.user[:email]).to eq("test@example.com")

        # Send welcome email using shared context
        email_result = welcome_email_task.call(registration_result.context)

        expect(email_result).to be_success
        expect(email_result.context.email_sent).to be(true)
        expect(email_result.context.email_id).to match(/^email_\d+$/)

        # Create audit log using accumulated context
        audit_result = audit_log_task.call(email_result.context)

        expect(audit_result).to be_success
        expect(audit_result.context.audit_entry[:action]).to eq("user_registration")
        expect(audit_result.context.audit_entry[:success]).to be(true)

        # Verify chain tracking
        expect(audit_result.chain.results.size).to eq(3)
        all_same_chain = audit_result.chain.results.all? { |r| r.chain.id == audit_result.chain.id }
        expect(all_same_chain).to be(true)

        CMDx::Chain.clear
      end
    end

    context "with error handling workflow" do
      it "handles validation failure gracefully" do
        registration_result = user_registration_task.call(
          email: "invalid_email",
          name: "Test User"
        )

        expect(registration_result).to be_failed
        expect(registration_result.metadata[:reason]).to eq("Invalid email")

        # Subsequent tasks handle missing data
        email_result = welcome_email_task.call(registration_result.context)

        expect(email_result).to be_skipped
        expect(email_result.metadata[:reason]).to eq("No user to email")

        # Audit captures the failure
        audit_result = audit_log_task.call(email_result.context)

        expect(audit_result).to be_success
        expect(audit_result.context.audit_entry[:success]).to be(false)
        expect(audit_result.context.audit_entry[:user_id]).to be_nil

        CMDx::Chain.clear
      end
    end

    context "with conditional execution" do
      it "skips welcome email when disabled" do
        registration_result = user_registration_task.call(
          email: "test@example.com",
          name: "Test User",
          send_welcome: false
        )

        expect(registration_result).to be_success

        email_result = welcome_email_task.call(registration_result.context)

        expect(email_result).to be_skipped
        expect(email_result.metadata[:reason]).to eq("Welcome email disabled")
        expect(email_result.context.email_sent).to be_nil

        CMDx::Chain.clear
      end
    end
  end
end
