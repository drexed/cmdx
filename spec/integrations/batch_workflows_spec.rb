# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Batch Workflows", type: :integration do
  describe "E-commerce Order Processing" do
    let(:validate_order_task) do
      Class.new(CMDx::Task) do
        required :order_id, type: :integer

        def call
          context.order = { id: order_id, status: "pending", items: %w[item1 item2] }
          context.validation_passed = true
        end
      end
    end

    let(:calculate_tax_task) do
      Class.new(CMDx::Task) do
        def call
          return fail!(reason: "No order to calculate tax") unless context.order

          context.tax_amount = context.order[:items].size * 5.0
          context.order[:tax] = context.tax_amount
        end
      end
    end

    let(:charge_payment_task) do
      Class.new(CMDx::Task) do
        def call
          return fail!(reason: "No tax calculated") unless context.tax_amount

          context.payment_id = "pay_#{Time.now.to_i}"
          context.total_charged = context.tax_amount + 50.0
        end
      end
    end

    let(:fulfill_order_task) do
      Class.new(CMDx::Task) do
        def call
          return fail!(reason: "No payment processed") unless context.payment_id

          context.tracking_number = "TRK#{rand(1000..9999)}"
          context.order[:status] = "fulfilled"
        end
      end
    end

    let(:order_processing_batch) do
      validate_task = validate_order_task
      tax_task = calculate_tax_task
      payment_task = charge_payment_task
      fulfill_task = fulfill_order_task

      Class.new(CMDx::Batch) do
        process validate_task
        process tax_task
        process payment_task
        process fulfill_task
      end
    end

    context "when all tasks succeed" do
      it "processes the order through the complete pipeline" do
        result = order_processing_batch.call(order_id: 123)

        expect(result).to be_successful_task
        expect(result.context.order[:id]).to eq(123)
        expect(result.context.order[:status]).to eq("fulfilled")
        expect(result.context.validation_passed).to be(true)
        expect(result.context.tax_amount).to eq(10.0)
        expect(result.context.payment_id).to match(/^pay_\d+$/)
        expect(result.context.tracking_number).to match(/^TRK\d{4}$/)
        expect(result.context.total_charged).to eq(60.0)
      end

      it "maintains context throughout the pipeline" do
        result = order_processing_batch.call(order_id: 456)

        context_data = result.context.to_h
        expect(context_data).to include(
          order_id: 456,
          validation_passed: true,
          tax_amount: 10.0,
          total_charged: 60.0
        )
        expect(context_data[:order]).to include(
          id: 456,
          status: "fulfilled",
          tax: 10.0
        )
      end
    end

    context "when a task fails" do
      let(:failing_payment_task) do
        Class.new(CMDx::Task) do
          def call
            fail!(reason: "Payment declined", code: "PAYMENT_FAILED")
          end
        end
      end

      let(:failing_batch) do
        validate_task = validate_order_task
        tax_task = calculate_tax_task
        failing_task = failing_payment_task
        fulfill_task = fulfill_order_task

        Class.new(CMDx::Batch) do
          process validate_task
          process tax_task
          process failing_task
          process fulfill_task
        end
      end

      it "halts execution after payment failure" do
        result = failing_batch.call(order_id: 123)

        expect(result).to be_failed_task
        expect(result.context.validation_passed).to be(true)
        expect(result.context.tax_amount).to eq(10.0)
        expect(result.context.payment_id).to be_nil
        expect(result.context.tracking_number).to be_nil
      end
    end
  end

  describe "User Registration Workflow" do
    let(:validate_user_data_task) do
      Class.new(CMDx::Task) do
        required :email, type: :string
        required :name, type: :string

        def call
          return fail!(reason: "Invalid email") unless email.include?("@")
          return fail!(reason: "Name too short") if name.length < 2

          context.user_data = { email: email, name: name, id: rand(1000..9999) }
        end
      end
    end

    let(:create_user_account_task) do
      Class.new(CMDx::Task) do
        def call
          return fail!(reason: "No user data") unless context.user_data

          context.user_account = {
            id: context.user_data[:id],
            email: context.user_data[:email],
            name: context.user_data[:name],
            created_at: Time.now
          }
        end
      end
    end

    let(:send_welcome_email_task) do
      Class.new(CMDx::Task) do
        def call
          return skip!(reason: "No user account created") unless context.user_account

          context.welcome_email_sent = true
          context.email_id = "email_#{context.user_account[:id]}"
        end
      end
    end

    let(:setup_user_preferences_task) do
      Class.new(CMDx::Task) do
        def call
          return fail!(reason: "No user account") unless context.user_account

          context.preferences_created = true
          context.user_account[:preferences] = { theme: "light", notifications: true }
        end
      end
    end

    let(:user_registration_batch) do
      validate_task = validate_user_data_task
      create_task = create_user_account_task
      email_task = send_welcome_email_task
      preferences_task = setup_user_preferences_task

      Class.new(CMDx::Batch) do
        process validate_task
        process create_task
        process email_task, preferences_task
      end
    end

    context "with valid user data" do
      it "completes the full registration workflow" do
        result = user_registration_batch.call(
          email: "user@example.com",
          name: "John Doe"
        )

        expect(result).to be_successful_task
        expect(result.context.user_data[:email]).to eq("user@example.com")
        expect(result.context.user_account).to include(
          email: "user@example.com",
          name: "John Doe"
        )
        expect(result.context.welcome_email_sent).to be(true)
        expect(result.context.preferences_created).to be(true)
        expect(result.context.user_account[:preferences]).to eq({ theme: "light", notifications: true })
      end
    end

    context "with invalid user data" do
      it "fails validation and halts the workflow" do
        result = user_registration_batch.call(
          email: "invalid_email",
          name: "A"
        )

        expect(result).to be_failed_task
        expect(result.context.user_data).to be_nil
        expect(result.context.user_account).to be_nil
        expect(result.context.welcome_email_sent).to be_nil
      end
    end
  end

  describe "Conditional Execution Workflows" do
    let(:always_execute_task) do
      Class.new(CMDx::Task) do
        def call
          context.always_executed = true
        end
      end
    end

    let(:premium_feature_task) do
      Class.new(CMDx::Task) do
        def call
          context.premium_feature_activated = true
        end
      end
    end

    let(:notification_task) do
      Class.new(CMDx::Task) do
        def call
          context.notification_sent = true
        end
      end
    end

    let(:conditional_batch) do
      always_task = always_execute_task
      premium_task = premium_feature_task
      notify_task = notification_task

      Class.new(CMDx::Batch) do
        process always_task

        process premium_task, if: proc { context.user_type == "premium" }

        process notify_task, unless: proc { context.disable_notifications == true }
      end
    end

    context "with premium user and notifications enabled" do
      it "executes all applicable tasks" do
        result = conditional_batch.call(
          user_type: "premium",
          disable_notifications: false
        )

        expect(result).to be_successful_task
        expect(result.context.always_executed).to be(true)
        expect(result.context.premium_feature_activated).to be(true)
        expect(result.context.notification_sent).to be(true)
      end
    end

    context "with regular user and notifications disabled" do
      it "skips conditional tasks appropriately" do
        result = conditional_batch.call(
          user_type: "regular",
          disable_notifications: true
        )

        expect(result).to be_successful_task
        expect(result.context.always_executed).to be(true)
        expect(result.context.premium_feature_activated).to be_nil
        expect(result.context.notification_sent).to be_nil
      end
    end

    context "with premium user and notifications disabled" do
      it "executes premium features but skips notifications" do
        result = conditional_batch.call(
          user_type: "premium",
          disable_notifications: true
        )

        expect(result).to be_successful_task
        expect(result.context.always_executed).to be(true)
        expect(result.context.premium_feature_activated).to be(true)
        expect(result.context.notification_sent).to be_nil
      end
    end
  end

  describe "Custom Halt Behavior" do
    let(:critical_task) do
      Class.new(CMDx::Task) do
        def call
          return skip!(reason: "Not needed in test mode") if context.test_mode

          context.critical_operation_completed = true
        end
      end
    end

    let(:optional_task) do
      Class.new(CMDx::Task) do
        def call
          return fail!(reason: "Optional service unavailable") if context.service_down

          context.optional_completed = true
        end
      end
    end

    let(:cleanup_task) do
      Class.new(CMDx::Task) do
        def call
          context.cleanup_performed = true
        end
      end
    end

    context "with strict halt behavior" do
      let(:strict_batch) do
        critical = critical_task
        optional = optional_task
        cleanup = cleanup_task

        Class.new(CMDx::Batch) do
          process critical, batch_halt: [CMDx::Result::FAILED, CMDx::Result::SKIPPED]
          process optional
          process cleanup
        end
      end

      it "halts on skipped critical task" do
        result = strict_batch.call(test_mode: true)

        expect(result).to be_skipped_task
        expect(result.context.critical_operation_completed).to be_nil
        expect(result.context.optional_completed).to be_nil
        expect(result.context.cleanup_performed).to be_nil
      end
    end

    context "with flexible halt behavior" do
      let(:flexible_batch) do
        critical = critical_task
        optional = optional_task
        cleanup = cleanup_task

        Class.new(CMDx::Batch) do
          process critical, batch_halt: [CMDx::Result::FAILED]
          process optional, batch_halt: []
          process cleanup
        end
      end

      it "continues after skipped critical task" do
        result = flexible_batch.call(test_mode: true, service_down: false)

        expect(result).to be_successful_task
        expect(result.context.critical_operation_completed).to be_nil
        expect(result.context.optional_completed).to be(true)
        expect(result.context.cleanup_performed).to be(true)
      end

      it "continues after failed optional task" do
        result = flexible_batch.call(
          test_mode: false,
          service_down: true
        )

        expect(result).to be_successful_task
        expect(result.context.critical_operation_completed).to be(true)
        expect(result.context.optional_completed).to be_nil
        expect(result.context.cleanup_performed).to be(true)
      end
    end
  end

  describe "Nested Batch Workflows" do
    let(:validate_input_task) do
      Class.new(CMDx::Task) do
        def call
          context.input_validated = true
        end
      end
    end

    let(:sanitize_data_task) do
      Class.new(CMDx::Task) do
        def call
          context.data_sanitized = true
          context.pre_processing_complete = true
        end
      end
    end

    let(:transform_data_task) do
      Class.new(CMDx::Task) do
        def call
          return fail!(reason: "Pre-processing not complete") unless context.pre_processing_complete

          context.data_transformed = true
        end
      end
    end

    let(:apply_business_logic_task) do
      Class.new(CMDx::Task) do
        def call
          context.business_logic_applied = true
          context.core_processing_complete = true
        end
      end
    end

    let(:generate_report_task) do
      Class.new(CMDx::Task) do
        def call
          return skip!(reason: "Skip reporting") if context.skip_reporting

          context.report_generated = true
        end
      end
    end

    let(:send_notifications_task) do
      Class.new(CMDx::Task) do
        def call
          context.notifications_sent = true
        end
      end
    end

    let(:pre_processing_batch) do
      validate_task = validate_input_task
      sanitize_task = sanitize_data_task

      Class.new(CMDx::Batch) do
        process validate_task
        process sanitize_task
      end
    end

    let(:core_processing_batch) do
      transform_task = transform_data_task
      business_task = apply_business_logic_task

      Class.new(CMDx::Batch) do
        process transform_task
        process business_task
      end
    end

    let(:post_processing_batch) do
      report_task = generate_report_task
      notify_task = send_notifications_task

      Class.new(CMDx::Batch) do
        process report_task
        process notify_task
      end
    end

    let(:master_batch) do
      pre_batch = pre_processing_batch
      core_batch = core_processing_batch
      post_batch = post_processing_batch

      Class.new(CMDx::Batch) do
        process pre_batch

        process core_batch, if: proc { context.pre_processing_complete }

        process post_batch, unless: proc { context.skip_post_processing }
      end
    end

    context "with complete workflow execution" do
      it "executes all nested batches successfully" do
        result = master_batch.call(
          skip_post_processing: false,
          skip_reporting: false
        )

        expect(result).to be_successful_task
        expect(result.context.input_validated).to be(true)
        expect(result.context.data_sanitized).to be(true)
        expect(result.context.pre_processing_complete).to be(true)
        expect(result.context.data_transformed).to be(true)
        expect(result.context.business_logic_applied).to be(true)
        expect(result.context.core_processing_complete).to be(true)
        expect(result.context.report_generated).to be(true)
        expect(result.context.notifications_sent).to be(true)
      end
    end

    context "with conditional batch execution" do
      it "skips post-processing when configured" do
        result = master_batch.call(
          skip_post_processing: true
        )

        expect(result).to be_successful_task
        expect(result.context.pre_processing_complete).to be(true)
        expect(result.context.core_processing_complete).to be(true)
        expect(result.context.report_generated).to be_nil
        expect(result.context.notifications_sent).to be_nil
      end
    end
  end

  describe "Data Processing Pipeline" do
    let(:load_data_task) do
      Class.new(CMDx::Task) do
        required :source, type: :string

        def call
          return fail!(reason: "Invalid source") unless %w[file api database].include?(source)

          context.raw_data = Array.new(rand(3..7)) { |i| "record_#{i}" }
          context.data_loaded = true
        end
      end
    end

    let(:validate_data_task) do
      Class.new(CMDx::Task) do
        def call
          return fail!(reason: "No data to validate") unless context.raw_data

          valid_records = context.raw_data.select { |record| record.include?("record") }
          context.valid_data = valid_records
          context.validation_stats = {
            total: context.raw_data.size,
            valid: valid_records.size,
            invalid: context.raw_data.size - valid_records.size
          }
        end
      end
    end

    let(:transform_data_task) do
      Class.new(CMDx::Task) do
        def call
          return skip!(reason: "No valid data to transform") if context.valid_data && context.valid_data.empty?

          context.transformed_data = context.valid_data.map(&:upcase)
        end
      end
    end

    let(:save_data_task) do
      Class.new(CMDx::Task) do
        def call
          return skip!(reason: "No transformed data to save") unless context.transformed_data

          context.saved_records = context.transformed_data.size
          context.save_timestamp = Time.now
        end
      end
    end

    let(:data_pipeline_batch) do
      load_task = load_data_task
      validate_task = validate_data_task
      transform_task = transform_data_task
      save_task = save_data_task

      Class.new(CMDx::Batch) do
        task_settings!(
          batch_halt: [CMDx::Result::FAILED],
          tags: %i[data_processing pipeline]
        )

        process load_task
        process validate_task
        process transform_task
        process save_task
      end
    end

    context "with successful data processing" do
      it "processes data through the complete pipeline" do
        result = data_pipeline_batch.call(source: "file")

        expect(result).to be_successful_task
        expect(result.context.data_loaded).to be(true)
        expect(result.context.validation_stats[:total]).to be > 0
        expect(result.context.transformed_data).to all(match(/^RECORD_\d+$/))
        expect(result.context.saved_records).to eq(result.context.transformed_data.size)
        expect(result.context.save_timestamp).to be_a(Time)
      end

      it "maintains data transformation integrity" do
        result = data_pipeline_batch.call(source: "api")

        original_count = result.context.raw_data.size
        valid_count = result.context.validation_stats[:valid]
        transformed_count = result.context.transformed_data.size
        saved_count = result.context.saved_records

        expect(valid_count).to eq(original_count)
        expect(transformed_count).to eq(valid_count)
        expect(saved_count).to eq(transformed_count)
      end
    end

    context "with invalid data source" do
      it "fails at the data loading stage" do
        result = data_pipeline_batch.call(source: "invalid_source")

        expect(result).to be_failed_task
        expect(result.context.data_loaded).to be_nil
        expect(result.context.validation_stats).to be_nil
        expect(result.context.transformed_data).to be_nil
        expect(result.context.saved_records).to be_nil
      end
    end
  end

  describe "Error Handling and Recovery" do
    let(:risky_task) do
      Class.new(CMDx::Task) do
        def call
          return fail!(reason: "Service unavailable", retry_after: 30) if context.service_down

          context.operation_completed = true
        end
      end
    end

    let(:fallback_task) do
      Class.new(CMDx::Task) do
        def call
          context.fallback_used = true
          context.fallback_result = "Alternative processing completed"
        end
      end
    end

    let(:cleanup_task) do
      Class.new(CMDx::Task) do
        def call
          context.resources_cleaned = true
        end
      end
    end

    let(:resilient_batch) do
      risky = risky_task
      fallback = fallback_task
      cleanup = cleanup_task

      Class.new(CMDx::Batch) do
        task_settings!(batch_halt: [])

        process risky
        process fallback, if: proc { context.operation_completed.nil? }
        process cleanup
      end
    end

    context "when primary operation succeeds" do
      it "completes without using fallback" do
        result = resilient_batch.call(service_down: false)

        expect(result).to be_successful_task
        expect(result.context.operation_completed).to be(true)
        expect(result.context.fallback_used).to be_nil
        expect(result.context.resources_cleaned).to be(true)
      end
    end

    context "when primary operation fails" do
      it "uses fallback and completes successfully" do
        result = resilient_batch.call(service_down: true)

        expect(result).to be_successful_task
        expect(result.context.operation_completed).to be_nil
        expect(result.context.fallback_used).to be(true)
        expect(result.context.fallback_result).to eq("Alternative processing completed")
        expect(result.context.resources_cleaned).to be(true)
      end
    end
  end
end
