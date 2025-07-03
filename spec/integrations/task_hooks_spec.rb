# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task Hooks Integration" do
  # Create a mock logging service to track hook execution
  let(:execution_log) { [] }
  let(:notification_service) { double("NotificationService", send: true) }
  let(:metric_service) { double("MetricService", increment: true, track: true) }

  # Base application task with inherited hooks
  let(:application_task) do
    log = execution_log
    Class.new(CMDx::Task) do
      before_execution :log_task_start
      after_execution :log_task_end
      on_failed :report_failure
      on_success :track_success_metrics

      private

      define_method(:log_task_start) do
        log << "#{self.class.name}:task_start"
      end

      define_method(:log_task_end) do
        log << "#{self.class.name}:task_end"
      end

      define_method(:report_failure) do
        log << "#{self.class.name}:failure_reported"
      end

      define_method(:track_success_metrics) do
        log << "#{self.class.name}:success_tracked"
      end
    end
  end

  describe "Hook Declaration Patterns" do
    context "with method name declarations" do
      let(:order_processing_task) do
        log = execution_log
        Class.new(CMDx::Task) do
          required :order_id, type: :integer

          before_validation :validate_order_exists
          after_validation :prepare_order_data
          before_execution :lock_order
          after_execution :unlock_order
          on_success :send_confirmation

          def call
            context.order = { id: order_id, status: "processed" }
          end

          private

          define_method(:validate_order_exists) do
            log << "order_validation:exists_check"
          end

          define_method(:prepare_order_data) do
            log << "order_validation:data_prepared"
          end

          define_method(:lock_order) do
            log << "order_execution:locked"
          end

          define_method(:unlock_order) do
            log << "order_execution:unlocked"
          end

          define_method(:send_confirmation) do
            log << "order_success:confirmation_sent"
          end
        end
      end

      it "executes method-based hooks in correct order" do
        result = order_processing_task.call(order_id: 123)

        expect(result).to be_successful_task
        expect(execution_log).to eq([
                                      "order_execution:locked",
                                      "order_validation:exists_check",
                                      "order_validation:data_prepared",
                                      "order_success:confirmation_sent",
                                      "order_execution:unlocked"
                                    ])
      end
    end

    context "with proc and lambda declarations" do
      let(:user_registration_task) do
        log = execution_log
        notification_svc = notification_service

        Class.new(CMDx::Task) do
          required :email, type: :string
          required :username, type: :string

          # Proc declaration
          before_validation proc { log << "validation:email_format_check" }

          # Lambda declaration
          on_success -> { log << "success:welcome_email_queued" }

          # Lambda with service integration
          on_complete :complete_user_registration

          def call
            context.user = { email: email, username: username, status: "active" }
          end

          private

          define_method(:complete_user_registration) do
            log << "complete:user_registered"
            notification_svc.send(:email, "Welcome #{username}!")
          end
        end
      end

      it "executes proc and lambda hooks correctly" do
        result = user_registration_task.call(email: "user@example.com", username: "newuser")

        expect(result).to be_successful_task
        expect(execution_log).to include(
          "validation:email_format_check",
          "success:welcome_email_queued",
          "complete:user_registered"
        )
        expect(notification_service).to have_received(:send).with(:email, "Welcome newuser!")
      end
    end

    context "with block declarations" do
      let(:file_processing_task) do
        log = execution_log
        Class.new(CMDx::Task) do
          required :file_path, type: :string

          before_execution do
            log << "file_processing:started"
            context.processing_start = Time.now
          end

          after_execution do
            processing_time = Time.now - context.processing_start
            log << "file_processing:completed:#{processing_time.round(3)}"
          end

          on_success do
            log << "file_processing:success:cleanup_temp_files"
            context.cleanup_performed = true
          end

          def call
            context.file_data = { path: file_path, size: 1024, processed: true }
          end
        end
      end

      it "executes block-based hooks with access to context" do
        result = file_processing_task.call(file_path: "/tmp/test.csv")

        expect(result).to be_successful_task
        expect(execution_log.first).to eq("file_processing:started")
        expect(execution_log.last).to match(/file_processing:completed:\d+\.\d+/)
        expect(execution_log).to include("file_processing:success:cleanup_temp_files")
        expect(result.context.cleanup_performed).to be(true)
      end
    end

    context "with multiple hooks for same event" do
      let(:payment_processing_task) do
        log = execution_log
        metric_svc = metric_service

        Class.new(CMDx::Task) do
          required :amount, type: :float
          required :payment_method, type: :string

          # Multiple success hooks
          on_success :update_account_balance
          on_success :send_receipt
          on_success :log_transaction
          on_success -> { metric_svc.increment("payments.processed") }

          def call
            context.transaction = {
              amount: amount,
              method: payment_method,
              status: "completed"
            }
          end

          private

          define_method(:update_account_balance) do
            log << "payment_success:balance_updated"
          end

          define_method(:send_receipt) do
            log << "payment_success:receipt_sent"
          end

          define_method(:log_transaction) do
            log << "payment_success:transaction_logged"
          end
        end
      end

      it "executes multiple hooks in declaration order" do
        result = payment_processing_task.call(amount: 99.99, payment_method: "credit_card")

        expect(result).to be_successful_task
        expect(execution_log).to eq([
                                      "payment_success:balance_updated",
                                      "payment_success:receipt_sent",
                                      "payment_success:transaction_logged"
                                    ])
        expect(metric_service).to have_received(:increment).with("payments.processed")
      end
    end
  end

  describe "Hook Types and Execution Order" do
    let(:comprehensive_task) do
      log = execution_log
      Class.new(CMDx::Task) do
        required :user_id, type: :integer

        # Validation hooks
        define_method(:before_validation_hook) { log << "1:before_validation" }
        before_validation :before_validation_hook

        define_method(:after_validation_hook) { log << "4:after_validation" }
        after_validation :after_validation_hook

        # Execution hooks
        define_method(:before_execution_hook) { log << "2:before_execution" }
        before_execution :before_execution_hook

        define_method(:after_execution_hook) { log << "10:after_execution" }
        after_execution :after_execution_hook

        # State hooks
        define_method(:on_executing_hook) { log << "3:on_executing" }
        on_executing :on_executing_hook

        define_method(:on_complete_hook) { log << "6:on_complete" }
        on_complete :on_complete_hook

        define_method(:on_executed_hook) { log << "8:on_executed" }
        on_executed :on_executed_hook

        # Status hooks
        define_method(:on_success_hook) { log << "7:on_success" }
        on_success :on_success_hook

        # Outcome hooks
        define_method(:on_good_hook) { log << "9:on_good" }
        on_good :on_good_hook

        define_method(:call) do
          log << "5:call_method"
          context.result = "Task completed for user #{user_id}"
        end
      end
    end

    it "executes all hook types in correct order" do
      result = comprehensive_task.call(user_id: 456)

      expect(result).to be_successful_task
      expect(execution_log).to eq([
                                    "2:before_execution",
                                    "3:on_executing",
                                    "1:before_validation",
                                    "4:after_validation",
                                    "5:call_method",
                                    "6:on_complete",
                                    "8:on_executed",
                                    "7:on_success",
                                    "9:on_good",
                                    "10:after_execution"
                                  ])
    end

    context "when task fails" do
      let(:failing_task) do
        log = execution_log
        Class.new(CMDx::Task) do
          required :will_fail, type: :boolean

          define_method(:before_validation_hook) { log << "1:before_validation" }
          before_validation :before_validation_hook

          define_method(:before_execution_hook) { log << "2:before_execution" }
          before_execution :before_execution_hook

          define_method(:on_executing_hook) { log << "3:on_executing" }
          on_executing :on_executing_hook

          define_method(:after_validation_hook) { log << "4:after_validation" }
          after_validation :after_validation_hook

          define_method(:on_interrupted_hook) { log << "6:on_interrupted" }
          on_interrupted :on_interrupted_hook

          define_method(:on_failed_hook) { log << "7:on_failed" }
          on_failed :on_failed_hook

          define_method(:on_executed_hook) { log << "8:on_executed" }
          on_executed :on_executed_hook

          define_method(:on_bad_hook) { log << "9:on_bad" }
          on_bad :on_bad_hook

          define_method(:after_execution_hook) { log << "10:after_execution" }
          after_execution :after_execution_hook

          define_method(:call) do
            log << "5:call_method"
            fail!("Intentional failure") if will_fail
          end
        end
      end

      it "executes failure hooks in correct order" do
        result = failing_task.call(will_fail: true)

        expect(result).to be_failed_task
        expect(execution_log).to eq([
                                      "2:before_execution",
                                      "3:on_executing",
                                      "1:before_validation",
                                      "4:after_validation",
                                      "5:call_method",
                                      "6:on_interrupted",
                                      "8:on_executed",
                                      "7:on_failed",
                                      "9:on_bad",
                                      "10:after_execution"
                                    ])
      end
    end

    context "when task is skipped" do
      let(:skipping_task) do
        log = execution_log
        Class.new(CMDx::Task) do
          required :should_skip, type: :boolean

          define_method(:before_validation_hook) { log << "1:before_validation" }
          before_validation :before_validation_hook

          define_method(:before_execution_hook) { log << "2:before_execution" }
          before_execution :before_execution_hook

          define_method(:on_executing_hook) { log << "3:on_executing" }
          on_executing :on_executing_hook

          define_method(:after_validation_hook) { log << "4:after_validation" }
          after_validation :after_validation_hook

          define_method(:on_interrupted_hook) { log << "6:on_interrupted" }
          on_interrupted :on_interrupted_hook

          define_method(:on_skipped_hook) { log << "7:on_skipped" }
          on_skipped :on_skipped_hook

          define_method(:on_executed_hook) { log << "8:on_executed" }
          on_executed :on_executed_hook

          define_method(:on_good_hook) { log << "9:on_good" }
          on_good :on_good_hook

          define_method(:after_execution_hook) { log << "10:after_execution" }
          after_execution :after_execution_hook

          define_method(:call) do
            log << "5:call_method"
            skip! if should_skip
          end
        end
      end

      it "executes skip hooks in correct order" do
        result = skipping_task.call(should_skip: true)

        expect(result).to be_skipped_task
        expect(execution_log).to eq([
                                      "2:before_execution",
                                      "3:on_executing",
                                      "1:before_validation",
                                      "4:after_validation",
                                      "5:call_method",
                                      "6:on_interrupted",
                                      "8:on_executed",
                                      "7:on_skipped",
                                      "9:on_good",
                                      "10:after_execution"
                                    ])
      end
    end
  end

  describe "Conditional Execution" do
    context "with if conditions" do
      let(:conditional_task) do
        log = execution_log
        Class.new(CMDx::Task) do
          required :environment, type: :string
          required :user_type, type: :string
          optional :retry_count, type: :integer, default: 0

          # Method name condition
          on_success :send_notification, if: :notifications_enabled?

          # Proc condition
          on_failed :retry_operation, if: :can_retry?

          # String condition
          after_execution :detailed_logging, if: :development_environment?

          # Multiple conditions
          before_execution :expensive_setup, if: :production_env?, unless: :maintenance_mode?

          def call
            context.operation_result = "completed for #{user_type} user"
            fail!("Simulated failure") if retry_count > 0
          end

          private

          define_method(:notifications_enabled?) do
            user_type == "premium"
          end

          define_method(:production_env?) do
            environment == "production"
          end

          define_method(:development_environment?) do
            environment == "development"
          end

          define_method(:maintenance_mode?) do
            false # Simulated check
          end

          define_method(:send_notification) do
            log << "conditional:notification_sent"
          end

          define_method(:retry_operation) do
            log << "conditional:retry_scheduled"
          end

          define_method(:detailed_logging) do
            log << "conditional:detailed_log"
          end

          define_method(:expensive_setup) do
            log << "conditional:expensive_setup"
          end

          define_method(:can_retry?) do
            context.retry_count < 3
          end
        end
      end

      it "executes hooks only when conditions are met" do
        result = conditional_task.call(
          environment: "development",
          user_type: "premium"
        )

        expect(result).to be_successful_task
        expect(execution_log).to include("conditional:notification_sent")
        expect(execution_log).to include("conditional:detailed_log")
        expect(execution_log).not_to include("conditional:expensive_setup")
        expect(execution_log).not_to include("conditional:retry_scheduled")
      end

      it "executes retry hook when failure conditions are met" do
        result = conditional_task.call(
          environment: "production",
          user_type: "basic",
          retry_count: 1
        )

        expect(result).to be_failed_task
        expect(execution_log).to include("conditional:retry_scheduled")
        expect(execution_log).to include("conditional:expensive_setup")
        expect(execution_log).not_to include("conditional:notification_sent")
        expect(execution_log).not_to include("conditional:detailed_log")
      end
    end

    context "with unless conditions" do
      let(:unless_conditional_task) do
        log = execution_log
        Class.new(CMDx::Task) do
          required :skip_validation, type: :boolean, default: false
          required :maintenance_mode, type: :boolean, default: false

          before_validation :validate_inputs, unless: :skip_validation
          on_success :send_metrics, unless: :maintenance_mode

          def call
            context.processed = true
          end

          private

          define_method(:validate_inputs) do
            log << "unless:validation_performed"
          end

          define_method(:send_metrics) do
            log << "unless:metrics_sent"
          end
        end
      end

      it "skips hooks when unless conditions are true" do
        result = unless_conditional_task.call(
          skip_validation: true,
          maintenance_mode: true
        )

        expect(result).to be_successful_task
        expect(execution_log).not_to include("unless:validation_performed")
        expect(execution_log).not_to include("unless:metrics_sent")
      end

      it "executes hooks when unless conditions are false" do
        result = unless_conditional_task.call(
          skip_validation: false,
          maintenance_mode: false
        )

        expect(result).to be_successful_task
        expect(execution_log).to include("unless:validation_performed")
        expect(execution_log).to include("unless:metrics_sent")
      end
    end
  end

  describe "Hook Inheritance" do
    let(:order_processing_task) do
      log = execution_log
      app_task = application_task

      Class.new(app_task) do
        required :order_id, type: :integer

        before_validation :load_order
        on_success :send_confirmation
        on_failed :refund_payment, if: :payment_captured?

        def call
          context.order = { id: order_id, status: "processed", payment_captured: true }
        end

        private

        define_method(:load_order) do
          log << "#{self.class.name}:order_loaded"
        end

        define_method(:send_confirmation) do
          log << "#{self.class.name}:confirmation_sent"
        end

        define_method(:payment_captured?) do
          context.order[:payment_captured]
        end

        define_method(:refund_payment) do
          log << "#{self.class.name}:payment_refunded"
        end
      end
    end

    it "inherits hooks from parent class and executes them correctly" do
      result = order_processing_task.call(order_id: 789)

      expect(result).to be_successful_task

      # Should include both inherited and class-specific hooks
      expect(execution_log).to include("#{order_processing_task.name}:task_start")
      expect(execution_log).to include("#{order_processing_task.name}:order_loaded")
      expect(execution_log).to include("#{order_processing_task.name}:confirmation_sent")
      expect(execution_log).to include("#{order_processing_task.name}:success_tracked")
      expect(execution_log).to include("#{order_processing_task.name}:task_end")

      # Should not include failure-specific hooks
      expect(execution_log).not_to include("#{order_processing_task.name}:payment_refunded")
      expect(execution_log).not_to include("#{order_processing_task.name}:failure_reported")
    end

    context "when child task fails" do
      let(:failing_order_task) do
        log = execution_log
        app_task = application_task

        Class.new(app_task) do
          required :order_id, type: :integer

          before_validation :load_order
          on_failed :refund_payment, if: :payment_captured?

          def call
            context.order = { id: order_id, payment_captured: true }
            fail!("Order processing failed")
          end

          private

          define_method(:load_order) do
            log << "#{self.class.name}:order_loaded"
          end

          define_method(:payment_captured?) do
            context.order[:payment_captured]
          end

          define_method(:refund_payment) do
            log << "#{self.class.name}:payment_refunded"
          end
        end
      end

      it "executes both inherited and class-specific failure hooks" do
        result = failing_order_task.call(order_id: 999)

        expect(result).to be_failed_task
        expect(execution_log).to include("#{failing_order_task.name}:task_start")
        expect(execution_log).to include("#{failing_order_task.name}:order_loaded")
        expect(execution_log).to include("#{failing_order_task.name}:payment_refunded")
        expect(execution_log).to include("#{failing_order_task.name}:failure_reported")
        expect(execution_log).to include("#{failing_order_task.name}:task_end")
      end
    end
  end

  describe "Hook Classes" do
    # Create reusable hook classes
    let(:logging_hook_class) do
      log = execution_log
      Class.new(CMDx::Hook) do
        def initialize(level)
          @level = level
        end

        define_method(:call) do |task, hook_type|
          log << "hook_class:logging:#{@level}:#{hook_type}:#{task.class.name}"
        end
      end
    end

    let(:notification_hook_class) do
      log = execution_log
      notification_svc = notification_service

      Class.new(CMDx::Hook) do
        def initialize(channels)
          @channels = Array(channels)
        end

        define_method(:call) do |task, hook_type|
          return unless hook_type == :on_success

          @channels.each do |channel|
            log << "hook_class:notification:#{channel}"
            notification_svc.send(channel, "Task #{task.class.name} completed")
          end
        end
      end
    end

    let(:metric_hook_class) do
      log = execution_log
      metric_svc = metric_service

      Class.new(CMDx::Hook) do
        def initialize(metric_name)
          @metric_name = metric_name
        end

        define_method(:call) do |_task, hook_type|
          case hook_type
          when :before_execution
            log << "hook_class:metric:start:#{@metric_name}"
            metric_svc.track("#{@metric_name}.started", 1)
          when :on_success
            log << "hook_class:metric:success:#{@metric_name}"
            metric_svc.track("#{@metric_name}.completed", 1)
          when :on_failed
            log << "hook_class:metric:failed:#{@metric_name}"
            metric_svc.track("#{@metric_name}.failed", 1)
          end
        end
      end
    end

    context "with hook class registration" do
      let(:api_integration_task) do
        log = execution_log
        logging_hook = logging_hook_class
        notification_hook = notification_hook_class
        metric_hook = metric_hook_class

        Class.new(CMDx::Task) do
          required :api_endpoint, type: :string
          required :payload, type: :hash

          # Register hook classes
          register :before_execution, logging_hook.new(:debug)
          register :on_success, notification_hook.new(%i[email slack])
          register :before_execution, metric_hook.new("api_integration")
          register :on_success, metric_hook.new("api_integration")
          register :on_failed, metric_hook.new("api_integration")

          # Mix with traditional hooks
          after_execution :cleanup_resources

          def call
            context.api_response = {
              endpoint: api_endpoint,
              status: 200,
              data: payload
            }
          end

          private

          define_method(:cleanup_resources) do
            log << "traditional:cleanup_performed"
          end
        end
      end

      it "executes hook classes alongside traditional hooks" do
        result = api_integration_task.call(
          api_endpoint: "https://api.example.com/users",
          payload: { name: "John Doe", email: "john@example.com" }
        )

        expect(result).to be_successful_task

        # Hook class executions
        expect(execution_log).to include("hook_class:logging:debug:before_execution:#{api_integration_task.name}")
        expect(execution_log).to include("hook_class:metric:start:api_integration")
        expect(execution_log).to include("hook_class:notification:email")
        expect(execution_log).to include("hook_class:notification:slack")
        expect(execution_log).to include("hook_class:metric:success:api_integration")

        # Traditional hook execution
        expect(execution_log).to include("traditional:cleanup_performed")

        # Service calls
        expect(notification_service).to have_received(:send).with(:email, "Task #{api_integration_task.name} completed")
        expect(notification_service).to have_received(:send).with(:slack, "Task #{api_integration_task.name} completed")
        expect(metric_service).to have_received(:track).with("api_integration.started", 1)
        expect(metric_service).to have_received(:track).with("api_integration.completed", 1)
      end
    end

    context "with conditional hook class execution" do
      let(:conditional_hook_task) do
        execution_log
        metric_hook = metric_hook_class

        Class.new(CMDx::Task) do
          required :environment, type: :string
          required :enable_metrics, type: :boolean, default: true

          register :before_execution, metric_hook.new("conditional_task"), if: :metrics_enabled?
          register :on_success, metric_hook.new("conditional_task"), if: :metrics_enabled?
          register :on_failed, metric_hook.new("conditional_task"), unless: :environment_test?

          def call
            context.task_completed = true
            fail!("Test failure") if environment == "test_failure"
          end

          private

          define_method(:metrics_enabled?) do
            enable_metrics && environment != "test"
          end

          define_method(:environment_test?) do
            environment == "test"
          end
        end
      end

      it "executes hook classes based on conditions" do
        result = conditional_hook_task.call(
          environment: "production",
          enable_metrics: true
        )

        expect(result).to be_successful_task
        expect(execution_log).to include("hook_class:metric:start:conditional_task")
        expect(execution_log).to include("hook_class:metric:success:conditional_task")
      end

      it "skips hook classes when conditions are not met" do
        result = conditional_hook_task.call(
          environment: "test",
          enable_metrics: false
        )

        expect(result).to be_successful_task
        expect(execution_log).not_to include("hook_class:metric:start:conditional_task")
        expect(execution_log).not_to include("hook_class:metric:success:conditional_task")
      end
    end
  end

  describe "Real-world Integration Scenarios" do
    context "when using e-commerce order processing pipeline" do
      let(:ecommerce_order_task) do
        log = execution_log
        notification_svc = notification_service
        metric_svc = metric_service

        Class.new(CMDx::Task) do
          required :order_id, type: :integer
          required :customer_email, type: :string
          optional :priority, type: :string, default: "normal"

          # Validation phase
          before_validation :validate_order_exists
          after_validation :load_order_details

          # Execution phase
          before_execution :reserve_inventory
          after_execution :release_inventory_hold

          # Success pipeline
          on_success :charge_payment
          on_success :update_inventory
          on_success :send_confirmation_email
          on_success :schedule_shipping
          on_success -> { metric_svc.increment("orders.processed") }

          # Failure handling
          on_failed :rollback_payment, if: :payment_processed?
          on_failed :restore_inventory
          on_failed :notify_customer_service

          # Cleanup
          on_executed :log_order_processing_time
          after_execution :cleanup_session_data

          def call
            context.order_processing = {
              start_time: Time.now,
              order_id: order_id,
              customer: customer_email,
              priority: priority
            }

            # Simulate order processing
            context.order_status = "processed"
            context.payment_processed = true
            context.inventory_reserved = true
          end

          private

          define_method(:validate_order_exists) do
            log << "ecommerce:validation:order_exists"
          end

          define_method(:load_order_details) do
            log << "ecommerce:validation:details_loaded"
          end

          define_method(:reserve_inventory) do
            log << "ecommerce:execution:inventory_reserved"
          end

          define_method(:release_inventory_hold) do
            log << "ecommerce:execution:inventory_released"
          end

          define_method(:charge_payment) do
            log << "ecommerce:success:payment_charged"
          end

          define_method(:update_inventory) do
            log << "ecommerce:success:inventory_updated"
          end

          define_method(:send_confirmation_email) do
            log << "ecommerce:success:confirmation_sent"
            notification_svc.send(:email, "Order confirmation for #{customer_email}")
          end

          define_method(:schedule_shipping) do
            log << "ecommerce:success:shipping_scheduled"
          end

          define_method(:payment_processed?) do
            context.payment_processed
          end

          define_method(:rollback_payment) do
            log << "ecommerce:failure:payment_rolled_back"
          end

          define_method(:restore_inventory) do
            log << "ecommerce:failure:inventory_restored"
          end

          define_method(:notify_customer_service) do
            log << "ecommerce:failure:cs_notified"
          end

          define_method(:log_order_processing_time) do
            processing_time = Time.now - context.order_processing[:start_time]
            log << "ecommerce:executed:processing_time:#{processing_time.round(3)}"
          end

          define_method(:cleanup_session_data) do
            log << "ecommerce:cleanup:session_cleared"
          end
        end
      end

      it "processes successful order with complete hook pipeline" do
        result = ecommerce_order_task.call(
          order_id: 12_345,
          customer_email: "customer@example.com",
          priority: "high"
        )

        expect(result).to be_successful_task

        # Validation hooks
        expect(execution_log).to include("ecommerce:validation:order_exists")
        expect(execution_log).to include("ecommerce:validation:details_loaded")

        # Execution hooks
        expect(execution_log).to include("ecommerce:execution:inventory_reserved")
        expect(execution_log).to include("ecommerce:execution:inventory_released")

        # Success hooks
        expect(execution_log).to include("ecommerce:success:payment_charged")
        expect(execution_log).to include("ecommerce:success:inventory_updated")
        expect(execution_log).to include("ecommerce:success:confirmation_sent")
        expect(execution_log).to include("ecommerce:success:shipping_scheduled")

        # Cleanup hooks
        expect(execution_log).to include("ecommerce:cleanup:session_cleared")
        expect(execution_log).to include(match(/ecommerce:executed:processing_time:\d+\.\d+/))

        # Service integrations
        expect(notification_service).to have_received(:send).with(:email, "Order confirmation for customer@example.com")
        expect(metric_service).to have_received(:increment).with("orders.processed")

        # Should not execute failure hooks
        expect(execution_log).not_to include("ecommerce:failure:payment_rolled_back")
        expect(execution_log).not_to include("ecommerce:failure:inventory_restored")
      end
    end

    context "when using data processing pipeline with error recovery" do
      let(:data_processing_task) do
        log = execution_log
        Class.new(CMDx::Task) do
          required :data_source, type: :string
          required :batch_size, type: :integer, default: 100
          optional :retry_on_failure, type: :boolean, default: true

          before_execution :initialize_processing
          before_execution :validate_data_source

          on_executing :start_progress_tracking

          on_success :finalize_results
          on_success :archive_processed_data
          on_success :send_completion_report

          on_failed :log_failure_details
          on_failed :schedule_retry, if: :should_retry?
          on_failed :notify_administrators

          after_execution :cleanup_temp_files
          after_execution :update_processing_metrics

          def call
            context.processing_stats = {
              source: data_source,
              batch_size: batch_size,
              records_processed: 0,
              start_time: Time.now
            }

            # Simulate data processing
            if data_source == "invalid_source"
              fail!("Invalid data source")
            else
              context.processing_stats[:records_processed] = batch_size * 10
              context.processing_stats[:status] = "completed"
            end
          end

          private

          define_method(:initialize_processing) do
            log << "data:execution:initialized"
          end

          define_method(:validate_data_source) do
            log << "data:execution:source_validated"
          end

          define_method(:start_progress_tracking) do
            log << "data:executing:progress_started"
          end

          define_method(:finalize_results) do
            log << "data:success:results_finalized"
          end

          define_method(:archive_processed_data) do
            log << "data:success:data_archived"
          end

          define_method(:send_completion_report) do
            log << "data:success:report_sent"
          end

          define_method(:should_retry?) do
            retry_on_failure
          end

          define_method(:log_failure_details) do
            log << "data:failure:details_logged"
          end

          define_method(:schedule_retry) do
            log << "data:failure:retry_scheduled"
          end

          define_method(:notify_administrators) do
            log << "data:failure:admins_notified"
          end

          define_method(:cleanup_temp_files) do
            log << "data:cleanup:temp_files_removed"
          end

          define_method(:update_processing_metrics) do
            log << "data:cleanup:metrics_updated"
          end
        end
      end

      it "processes data successfully with complete pipeline" do
        result = data_processing_task.call(
          data_source: "valid_source.csv",
          batch_size: 500
        )

        expect(result).to be_successful_task
        expect(result.context.processing_stats[:records_processed]).to eq(5000)

        expect(execution_log).to include("data:execution:initialized")
        expect(execution_log).to include("data:executing:progress_started")
        expect(execution_log).to include("data:success:results_finalized")
        expect(execution_log).to include("data:success:data_archived")
        expect(execution_log).to include("data:cleanup:temp_files_removed")

        # Should not execute failure hooks
        expect(execution_log).not_to include("data:failure:details_logged")
      end

      it "handles failures with retry logic" do
        result = data_processing_task.call(
          data_source: "invalid_source",
          batch_size: 100,
          retry_on_failure: true
        )

        expect(result).to be_failed_task

        expect(execution_log).to include("data:execution:initialized")
        expect(execution_log).to include("data:failure:details_logged")
        expect(execution_log).to include("data:failure:retry_scheduled")
        expect(execution_log).to include("data:failure:admins_notified")
        expect(execution_log).to include("data:cleanup:temp_files_removed")

        # Should not execute success hooks
        expect(execution_log).not_to include("data:success:results_finalized")
      end
    end
  end
end
