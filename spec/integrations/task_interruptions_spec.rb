# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task Interruptions", type: :integration do
  describe "Skip! Method Interruptions" do
    let(:order_processing_task) do
      Class.new(CMDx::Task) do
        required :order_id, type: :integer
        optional :force_reprocess, type: :boolean, default: false

        def call
          # Create order with non-pending status to trigger skip
          context.order = { id: order_id, status: "cancelled", processed_at: nil }

          # Skip if order already processed
          if context.order[:processed_at] && !force_reprocess
            skip!(
              reason: "Order already processed",
              order_id: order_id,
              processed_at: context.order[:processed_at],
              reason_code: "ALREADY_PROCESSED"
            )
          end

          # Skip if prerequisites not met
          unless context.order[:status] == "pending"
            skip!(
              reason: "Order not in pending status",
              current_status: context.order[:status],
              expected_status: "pending"
            )
          end

          # Process order
          context.order[:processed_at] = Time.now
          context.order[:status] = "completed"
        end
      end
    end

    let(:notification_task) do
      Class.new(CMDx::Task) do
        required :user_id, type: :integer
        optional :force_send, type: :boolean, default: false

        def call
          context.user = { id: user_id, notifications_enabled: true, last_notification: nil }

          # Skip based on user preferences
          unless force_send || context.user[:notifications_enabled]
            skip!(
              reason: "User has notifications disabled",
              user_id: user_id,
              preference: "notifications_disabled"
            )
          end

          # Skip if already notified recently
          if context.user[:last_notification] && context.user[:last_notification] > 1.hour.ago
            skip!(
              reason: "Notification already sent recently",
              last_sent: context.user[:last_notification],
              cooldown_period: "1 hour"
            )
          end

          context.notification_sent = true
          context.user[:last_notification] = Time.now
        end
      end
    end

    context "when using call method" do
      it "returns skipped result without raising exception" do
        result = order_processing_task.call(order_id: 123)

        expect(result).to be_skipped_task
        expect(result.state).to eq("interrupted")
        expect(result.status).to eq("skipped")
        expect(result.good?).to be(true)
        expect(result.bad?).to be(true)
        expect(result.metadata[:reason]).to eq("Order not in pending status")
      end

      it "includes detailed skip metadata" do
        # Create custom task with forced disabled notifications
        disabled_notification_task = Class.new(CMDx::Task) do
          required :user_id, type: :integer

          def call
            context.user = { id: user_id, notifications_enabled: false, last_notification: nil }

            skip!(
              reason: "User has notifications disabled",
              user_id: user_id,
              preference: "notifications_disabled"
            )
          end
        end

        result = disabled_notification_task.call(user_id: 456)

        expect(result).to be_skipped_task
        expect(result.metadata[:user_id]).to eq(456)
        expect(result.metadata[:preference]).to eq("notifications_disabled")
        expect(result.metadata[:reason]).to eq("User has notifications disabled")
      end
    end

    context "when using call! method with default halt configuration" do
      it "returns skipped result without raising exception by default" do
        result = order_processing_task.call!(order_id: 123)

        expect(result).to be_skipped_task
        expect(result.metadata[:reason]).to eq("Order not in pending status")
      end
    end

    context "when using call! method with skip halt configuration" do
      let(:halt_on_skip_task) do
        Class.new(CMDx::Task) do
          cmd_settings!(task_halt: [CMDx::Result::FAILED, CMDx::Result::SKIPPED])

          def call
            skip!(reason: "Conditions not met", condition: "user_inactive")
          end
        end
      end

      it "raises CMDx::Skipped exception when configured to halt" do
        expect { halt_on_skip_task.call! }.to raise_error(CMDx::Skipped) do |error|
          expect(error.message).to eq("Conditions not met")
          expect(error.result.metadata[:condition]).to eq("user_inactive")
          expect(error.task).to be_a(halt_on_skip_task)
          expect(error.context).to eq(error.result.context)
        end
      end
    end
  end

  describe "Fail! Method Interruptions" do
    let(:payment_processing_task) do
      Class.new(CMDx::Task) do
        required :payment_amount, type: :float
        required :payment_method, type: :string

        def call
          # Fail on validation errors
          unless payment_amount > 0
            fail!(
              reason: "Payment amount must be positive",
              code: "INVALID_AMOUNT",
              provided_amount: payment_amount,
              minimum_amount: 0.01
            )
          end

          # Fail on business rule violations
          unless %w[credit_card debit_card paypal].include?(payment_method)
            fail!(
              reason: "Invalid payment method",
              code: "INVALID_METHOD",
              provided_method: payment_method,
              valid_methods: %w[credit_card debit_card paypal]
            )
          end

          # Simulate payment processing
          context.payment_processed = true
          context.transaction_id = "txn_#{SecureRandom.hex(8)}"
        end
      end
    end

    let(:user_creation_task) do
      Class.new(CMDx::Task) do
        required :email, type: :string
        required :password, type: :string

        def call
          # Fail with detailed validation information
          unless email.include?("@")
            fail!(
              reason: "Invalid email format",
              code: "EMAIL_FORMAT_ERROR",
              field: "email",
              provided_value: email,
              required_format: "user@domain.com"
            )
          end

          if password.length < 8
            fail!(
              reason: "Password too short",
              code: "PASSWORD_LENGTH_ERROR",
              field: "password",
              current_length: password.length,
              minimum_length: 8,
              suggested_action: "Use at least 8 characters"
            )
          end

          context.user_created = true
          context.user_id = SecureRandom.uuid
        end
      end
    end

    context "when using call method" do
      it "returns failed result without raising exception" do
        result = payment_processing_task.call(payment_amount: -10.0, payment_method: "credit_card")

        expect(result).to be_failed_task
        expect(result.state).to eq("interrupted")
        expect(result.status).to eq("failed")
        expect(result.good?).to be(false)
        expect(result.bad?).to be(true)
        expect(result.metadata[:reason]).to eq("Payment amount must be positive")
      end

      it "includes comprehensive failure metadata" do
        result = payment_processing_task.call(payment_amount: 100.0, payment_method: "bitcoin")

        expect(result.metadata[:code]).to eq("INVALID_METHOD")
        expect(result.metadata[:provided_method]).to eq("bitcoin")
        expect(result.metadata[:valid_methods]).to eq(%w[credit_card debit_card paypal])
        expect(result.metadata[:reason]).to eq("Invalid payment method")
      end
    end

    context "when using call! method with default halt configuration" do
      it "raises CMDx::Failed exception for failures" do
        expect do
          user_creation_task.call!(email: "invalid-email", password: "pass")
        end.to raise_error(CMDx::Failed)

        begin
          user_creation_task.call!(email: "invalid-email", password: "pass")
        rescue CMDx::Failed => e
          expect(e.message).to eq("Invalid email format")
          expect(e.result.metadata[:code]).to eq("EMAIL_FORMAT_ERROR")
          expect(e.result.metadata[:field]).to eq("email")
          expect(e.task).to be_a(user_creation_task)
        end
      end

      it "provides access to complete fault context" do
        expect do
          payment_processing_task.call!(payment_amount: -5.0, payment_method: "credit_card")
        end.to raise_error(CMDx::Failed)

        begin
          payment_processing_task.call!(payment_amount: -5.0, payment_method: "credit_card")
        rescue CMDx::Failed => e
          expect(e.context.payment_amount).to eq(-5.0)
          expect(e.context.payment_method).to eq("credit_card")
          expect(e.chain).to be_a(CMDx::Chain)
          expect(e.result.runtime).to be_a(Numeric).or be_nil
        end
      end
    end
  end

  describe "Exception Handling and Unhandled Exceptions" do
    let(:exception_task) do
      Class.new(CMDx::Task) do
        required :simulate_error, type: :string

        def call
          case simulate_error
          when "runtime_error"
            raise StandardError, "Something went wrong"
          when "no_method_error"
            non_existent_method_call
          when "custom_error"
            raise ArgumentError, "Invalid argument provided"
          else
            context.operation_completed = true
          end
        end
      end
    end

    context "when using call method" do
      it "captures all unhandled exceptions as failed results" do
        result = exception_task.call(simulate_error: "runtime_error")

        expect(result).to be_failed_task
        expect(result.state).to eq("interrupted")
        expect(result.metadata[:reason]).to eq("[StandardError] Something went wrong")
        expect(result.metadata[:original_exception]).to be_a(StandardError)
        expect(result.metadata[:original_exception].message).to eq("Something went wrong")
      end

      it "captures NameError exceptions" do
        result = exception_task.call(simulate_error: "no_method_error")

        expect(result).to be_failed_task
        expect(result.metadata[:reason]).to include("NameError")
        expect(result.metadata[:reason]).to include("non_existent_method_call")
        expect(result.metadata[:original_exception]).to be_a(NameError)
      end

      it "preserves original exception details in metadata" do
        result = exception_task.call(simulate_error: "custom_error")

        original = result.metadata[:original_exception]
        expect(original).to be_a(ArgumentError)
        expect(original.message).to eq("Invalid argument provided")
        expect(original.backtrace).to be_a(Array)
        expect(original.backtrace.first).to include("task_interruptions_spec.rb")
      end
    end

    context "when using call! method" do
      it "allows unhandled exceptions to propagate directly" do
        expect do
          exception_task.call!(simulate_error: "runtime_error")
        end.to raise_error(StandardError, "Something went wrong")
      end

      it "propagates NameError exceptions" do
        expect do
          exception_task.call!(simulate_error: "no_method_error")
        end.to raise_error(NameError)

        begin
          exception_task.call!(simulate_error: "no_method_error")
        rescue NameError => e
          expect(e.message).to include("non_existent_method_call")
        end
      end
    end
  end

  describe "Fault Type Handling and Matching" do
    let(:validation_task) do
      Class.new(CMDx::Task) do
        required :data_type, type: :string

        def call
          case data_type
          when "skip_validation"
            skip!(reason: "Validation not required", validation_type: "optional")
          when "fail_validation"
            fail!(reason: "Validation failed", error_code: "VALIDATION_ERROR")
          else
            context.validation_passed = true
          end
        end
      end
    end

    let(:payment_task) do
      Class.new(CMDx::Task) do
        required :payment_status, type: :string

        def call
          case payment_status
          when "declined"
            fail!(reason: "Payment declined", code: "PAYMENT_DECLINED")
          when "insufficient_funds"
            fail!(reason: "Insufficient funds", code: "INSUFFICIENT_FUNDS")
          else
            context.payment_processed = true
          end
        end
      end
    end

    context "with basic fault type rescue" do
      it "handles CMDx::Skipped exceptions" do
        # Configure task to halt on skipped status
        skipping_task = Class.new(CMDx::Task) do
          cmd_settings!(task_halt: [CMDx::Result::SKIPPED, CMDx::Result::FAILED])

          def call
            skip!(reason: "Validation not required", validation_type: "optional")
          end
        end

        skipped_caught = false
        failed_caught = false

        begin
          skipping_task.call!
        rescue CMDx::Skipped => e
          skipped_caught = true
          expect(e.message).to eq("Validation not required")
          expect(e.result.metadata[:validation_type]).to eq("optional")
        rescue CMDx::Failed
          failed_caught = true
        end

        expect(skipped_caught).to be(true)
        expect(failed_caught).to be(false)
      end

      it "handles CMDx::Failed exceptions" do
        # Configure task to halt on failed status
        failing_task = Class.new(CMDx::Task) do
          cmd_settings!(task_halt: [CMDx::Result::FAILED])

          def call
            fail!(reason: "Validation failed", error_code: "VALIDATION_ERROR")
          end
        end

        failed_caught = false

        begin
          failing_task.call!
        rescue CMDx::Failed => e
          failed_caught = true
          expect(e.message).to eq("Validation failed")
          expect(e.result.metadata[:error_code]).to eq("VALIDATION_ERROR")
        end

        expect(failed_caught).to be(true)
      end
    end

    context "with task-specific fault matching using for?" do
      it "matches faults only from specific task types" do
        # Configure validation task to halt on failure
        validation_task_configured = Class.new(CMDx::Task) do
          cmd_settings!(task_halt: [CMDx::Result::FAILED])

          def call
            fail!(reason: "Validation failed", error_code: "VALIDATION_ERROR")
          end
        end

        # Configure payment task to halt on failure
        payment_task_configured = Class.new(CMDx::Task) do
          cmd_settings!(task_halt: [CMDx::Result::FAILED])

          def call
            fail!(reason: "Payment declined", code: "PAYMENT_DECLINED")
          end
        end

        validation_fault_caught = false
        payment_fault_caught = false

        begin
          validation_task_configured.call!
        rescue CMDx::Failed.for?(validation_task_configured) => e
          validation_fault_caught = true
          expect(e.task).to be_a(validation_task_configured)
        rescue CMDx::Failed.for?(payment_task_configured)
          payment_fault_caught = true
        end

        expect(validation_fault_caught).to be(true)
        expect(payment_fault_caught).to be(false)
      end

      it "matches faults from multiple task types" do
        # Configure payment task to halt on failure
        payment_task_configured = Class.new(CMDx::Task) do
          cmd_settings!(task_halt: [CMDx::Result::FAILED])

          def call
            fail!(reason: "Payment declined", code: "PAYMENT_DECLINED")
          end
        end

        # Configure validation task to halt on failure
        validation_task_configured = Class.new(CMDx::Task) do
          cmd_settings!(task_halt: [CMDx::Result::FAILED])

          def call
            fail!(reason: "Validation failed", error_code: "VALIDATION_ERROR")
          end
        end

        fault_caught = false

        begin
          payment_task_configured.call!
        rescue CMDx::Failed.for?(validation_task_configured, payment_task_configured) => e
          fault_caught = true
          expect(e.task).to be_a(payment_task_configured)
        end

        expect(fault_caught).to be(true)
      end
    end

    context "with custom fault matching using matches?" do
      it "matches faults based on error code metadata" do
        # Configure payment task to halt on failure
        payment_task_configured = Class.new(CMDx::Task) do
          cmd_settings!(task_halt: [CMDx::Result::FAILED])

          def call
            fail!(reason: "Payment declined", code: "PAYMENT_DECLINED")
          end
        end

        payment_declined_caught = false

        begin
          payment_task_configured.call!
        rescue CMDx::Failed.matches? { |f| f.result.metadata[:code] == "PAYMENT_DECLINED" } => e
          payment_declined_caught = true
          expect(e.result.metadata[:code]).to eq("PAYMENT_DECLINED")
        end

        expect(payment_declined_caught).to be(true)
      end

      it "matches faults based on complex conditions" do
        # Configure payment task to halt on failure
        payment_task_configured = Class.new(CMDx::Task) do
          cmd_settings!(task_halt: [CMDx::Result::FAILED])

          def call
            fail!(reason: "Insufficient funds", code: "INSUFFICIENT_FUNDS")
          end
        end

        complex_match_caught = false

        begin
          payment_task_configured.call!
        rescue CMDx::Failed.matches? do |f|
          f.result.failed? &&
            f.result.metadata[:reason]&.include?("funds") &&
            f.task.is_a?(payment_task_configured)
        end => e
          complex_match_caught = true
          expect(e.result.metadata[:code]).to eq("INSUFFICIENT_FUNDS")
        end

        expect(complex_match_caught).to be(true)
      end
    end
  end

  describe "Throw! Method and Fault Propagation" do
    let(:subtask_failing) do
      Class.new(CMDx::Task) do
        def call
          fail!(reason: "Subtask validation failed", component: "data_validator")
        end
      end
    end

    let(:subtask_skipping) do
      Class.new(CMDx::Task) do
        def call
          skip!(reason: "Subtask not needed", condition: "optional_feature_disabled")
        end
      end
    end

    let(:parent_task) do
      failing_sub = subtask_failing
      skipping_sub = subtask_skipping

      Class.new(CMDx::Task) do
        required :subtask_type, type: :string

        define_method :call do
          context.parent_started = true

          subtask_result = case subtask_type
                           when "failing"
                             failing_sub.call(context)
                           when "skipping"
                             skipping_sub.call(context)
                           else
                             CMDx::Result.new(self).tap(&:success!)
                           end

          # Propagate failures but allow skips
          throw!(subtask_result) if subtask_result.failed?

          context.parent_completed = true
        end
      end
    end

    let(:propagating_task) do
      failing_sub = subtask_failing

      Class.new(CMDx::Task) do
        define_method :call do
          validation_result = failing_sub.call(context)

          if validation_result.failed?
            throw!(validation_result, {
                     workflow_stage: "initial_validation",
                     attempted_at: Time.now,
                     can_retry: true,
                     propagated_by: self.class.name
                   })
          end

          context.main_work_done = true
        end
      end
    end

    context "when using call method" do
      it "propagates failure from subtask" do
        result = parent_task.call(subtask_type: "failing")

        expect(result).to be_failed_task
        expect(result.metadata[:reason]).to eq("Subtask validation failed")
        expect(result.metadata[:component]).to eq("data_validator")
        expect(result.context.parent_started).to be(true)
        expect(result.context.parent_completed).to be_nil
      end

      it "continues execution when subtask is skipped" do
        result = parent_task.call(subtask_type: "skipping")

        expect(result).to be_successful_task
        expect(result.context.parent_started).to be(true)
        expect(result.context.parent_completed).to be(true)
      end

      it "propagates with additional metadata" do
        result = propagating_task.call

        expect(result).to be_failed_task
        expect(result.metadata[:workflow_stage]).to eq("initial_validation")
        expect(result.metadata[:can_retry]).to be(true)
        expect(result.metadata[:propagated_by]).to eq(propagating_task.name)
        expect(result.metadata[:attempted_at]).to be_a(Time)
      end
    end

    context "when using call! method" do
      it "raises original fault type when propagated" do
        expect do
          parent_task.call!(subtask_type: "failing")
        end.to raise_error(CMDx::Failed)

        begin
          parent_task.call!(subtask_type: "failing")
        rescue CMDx::Failed => e
          expect(e.message).to eq("Subtask validation failed")
          expect(e.result.metadata[:component]).to eq("data_validator")
        end
      end

      it "maintains fault chain information" do
        expect do
          propagating_task.call!
        end.to raise_error(CMDx::Failed)

        begin
          propagating_task.call!
        rescue CMDx::Failed => e
          expect(e.result.metadata[:reason]).to eq("Subtask validation failed")
          expect(e.result.metadata[:workflow_stage]).to eq("initial_validation")
          expect(e.chain.results.size).to be >= 1
        end
      end
    end
  end

  describe "Task Halt Configuration Patterns" do
    let(:strict_task) do
      Class.new(CMDx::Task) do
        cmd_settings!(task_halt: [CMDx::Result::FAILED, CMDx::Result::SKIPPED])

        required :action, type: :string

        def call
          case action
          when "skip"
            skip!(reason: "Action skipped", action_type: "conditional")
          when "fail"
            fail!(reason: "Action failed", error_level: "critical")
          else
            context.action_completed = true
          end
        end
      end
    end

    let(:lenient_task) do
      Class.new(CMDx::Task) do
        cmd_settings!(task_halt: [])

        required :operation, type: :string

        def call
          case operation
          when "skip"
            skip!(reason: "Operation skipped")
          when "fail"
            fail!(reason: "Operation failed")
          else
            context.operation_completed = true
          end
        end
      end
    end

    let(:failure_only_task) do
      Class.new(CMDx::Task) do
        cmd_settings!(task_halt: [CMDx::Result::FAILED])

        required :mode, type: :string

        def call
          case mode
          when "skip"
            skip!(reason: "Mode skipped")
          when "fail"
            fail!(reason: "Mode failed")
          else
            context.mode_completed = true
          end
        end
      end
    end

    context "with strict halt configuration" do
      it "raises exception for skipped tasks" do
        expect do
          strict_task.call!(action: "skip")
        end.to raise_error(CMDx::Skipped)

        begin
          strict_task.call!(action: "skip")
        rescue CMDx::Skipped => e
          expect(e.result.metadata[:action_type]).to eq("conditional")
        end
      end

      it "raises exception for failed tasks" do
        expect do
          strict_task.call!(action: "fail")
        end.to raise_error(CMDx::Failed)

        begin
          strict_task.call!(action: "fail")
        rescue CMDx::Failed => e
          expect(e.result.metadata[:error_level]).to eq("critical")
        end
      end
    end

    context "with lenient halt configuration" do
      it "returns skipped result without exception" do
        result = lenient_task.call!(operation: "skip")

        expect(result).to be_skipped_task
        expect(result.metadata[:reason]).to eq("Operation skipped")
      end

      it "returns failed result without exception" do
        result = lenient_task.call!(operation: "fail")

        expect(result).to be_failed_task
        expect(result.metadata[:reason]).to eq("Operation failed")
      end
    end

    context "with failure-only halt configuration" do
      it "returns skipped result without exception" do
        result = failure_only_task.call!(mode: "skip")

        expect(result).to be_skipped_task
        expect(result.metadata[:reason]).to eq("Mode skipped")
      end

      it "raises exception for failed tasks" do
        expect do
          failure_only_task.call!(mode: "fail")
        end.to raise_error(CMDx::Failed, "Mode failed")
      end
    end
  end

  describe "Real-world Interruption Scenarios" do
    let(:data_processing_workflow) do
      Class.new(CMDx::Task) do
        required :data_source, type: :string
        optional :skip_validation, type: :boolean, default: false

        def call
          # Skip if data source not available
          unless %w[database api file].include?(data_source)
            skip!(
              reason: "Unsupported data source",
              provided_source: data_source,
              supported_sources: %w[database api file]
            )
          end

          # Skip validation if requested
          if skip_validation
            skip!(
              reason: "Validation skipped by request",
              skip_reason: "manual_override"
            )
          end

          # Fail if database connection issues
          if data_source == "database" && context[:db_unavailable]
            fail!(
              reason: "Database connection failed",
              code: "DB_UNAVAILABLE",
              retry_after: 30,
              fallback_available: true
            )
          end

          # Process data
          context.data_processed = true
          context.processing_time = Time.now
          context.record_count = rand(100..1000)
        end
      end
    end

    it "handles comprehensive skip scenarios" do
      result = data_processing_workflow.call(data_source: "redis")

      expect(result).to be_skipped_task
      expect(result.metadata[:provided_source]).to eq("redis")
      expect(result.metadata[:supported_sources]).to eq(%w[database api file])
    end

    it "handles validation skip requests" do
      result = data_processing_workflow.call(data_source: "api", skip_validation: true)

      expect(result).to be_skipped_task
      expect(result.metadata[:skip_reason]).to eq("manual_override")
    end

    it "handles infrastructure failure scenarios" do
      result = data_processing_workflow.call(data_source: "database", db_unavailable: true)

      expect(result).to be_failed_task
      expect(result.metadata[:code]).to eq("DB_UNAVAILABLE")
      expect(result.metadata[:retry_after]).to eq(30)
      expect(result.metadata[:fallback_available]).to be(true)
    end

    it "completes successfully under normal conditions" do
      result = data_processing_workflow.call(data_source: "file")

      expect(result).to be_successful_task
      expect(result.context.data_processed).to be(true)
      expect(result.context.record_count).to be_between(100, 1000)
    end
  end
end
