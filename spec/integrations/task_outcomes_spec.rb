# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task Outcomes", type: :integration do
  describe "Result Objects and Core Attributes" do
    let(:successful_task) do
      Class.new(CMDx::Task) do
        required :order_id, type: :integer
        optional :priority, type: :string, default: "normal"

        def call
          context.order = { id: order_id, status: "processed", priority: priority }
          context.processed_at = Time.now
          context.confirmation_code = "CONF-#{order_id}"
        end
      end
    end

    let(:long_running_task) do
      Class.new(CMDx::Task) do
        def call
          sleep(0.1) # Simulate processing time
          context.heavy_operation_completed = true
        end
      end
    end

    context "when task executes successfully" do
      it "provides comprehensive result information" do
        result = successful_task.call(order_id: 12_345, priority: "high")

        # Core result attributes
        expect(result).to be_a(CMDx::Result)
        expect(result.task).to be_a(successful_task)
        expect(result.context).to be_a(CMDx::Context)
        expect(result.chain).to be_a(CMDx::Chain)
        expect(result.metadata).to be_a(Hash)

        # Execution information
        expect(result.to_h[:id]).to be_a(String)
        expect(result.to_h[:id]).to match(/\A[\w-]+\z/)
        expect(result.state).to eq("complete")
        expect(result.status).to eq("success")
        expect(result.runtime).to be >= 0
        expect(result.index).to eq(0)
      end

      it "provides access to task context and data" do
        result = successful_task.call(order_id: 67_890)

        # Context access
        expect(result.context.order_id).to eq(67_890)
        expect(result.context.order[:id]).to eq(67_890)
        expect(result.context.order[:status]).to eq("processed")
        expect(result.context.processed_at).to be_a(Time)
        expect(result.context.confirmation_code).to eq("CONF-67890")

        # Context is accessible through result
        expect(result.context).to be_a(CMDx::Context)
      end

      it "measures execution runtime accurately" do
        result = long_running_task.call

        expect(result.runtime).to be >= 90
        expect(result.runtime).to be < 150
        expect(result.context.heavy_operation_completed).to be(true)
      end

      it "tracks position in execution chain" do
        result = successful_task.call(order_id: 111)

        expect(result.index).to eq(0)
        expect(result.chain.results[result.index]).to eq(result)
        expect(result.chain.results.size).to eq(1)
      end
    end

    context "with task serialization and inspection" do
      it "provides comprehensive hash serialization" do
        result = successful_task.call(order_id: 123)

        serialized = result.to_h
        expect(serialized).to include(
          class: nil,
          type: "Task",
          index: 0,
          state: "complete",
          status: "success",
          outcome: "success"
        )
        expect(serialized[:id]).to be_a(String)
        expect(serialized[:chain_id]).to be_a(String)
        expect(serialized[:metadata]).to be_a(Hash)
        expect(serialized[:runtime]).to be >= 0
      end

      it "provides human-readable string inspection" do
        result = successful_task.call(order_id: 456)

        string_repr = result.to_s
        expect(string_repr).to include("type=Task")
        expect(string_repr).to include("index=0")
        expect(string_repr).to include("state=complete")
        expect(string_repr).to include("status=success")
        expect(string_repr).to include("outcome=success")
      end
    end
  end

  describe "States and Execution Lifecycle" do
    let(:state_tracking_task) do
      Class.new(CMDx::Task) do
        def call
          context.business_logic_executed = true
        end
      end
    end

    let(:interrupting_task) do
      Class.new(CMDx::Task) do
        def call
          fail!(reason: "Validation failed", error_code: "VALIDATION_ERROR")
        end
      end
    end

    let(:skipping_task) do
      Class.new(CMDx::Task) do
        def call
          skip!(reason: "Already processed", processed_at: Time.now)
        end
      end
    end

    context "with successful execution states" do
      it "tracks state transitions through execution lifecycle" do
        result = state_tracking_task.call

        # After execution completion
        expect(result.initialized?).to be(false)
        expect(result.executing?).to be(false)
        expect(result.complete?).to be(true)
        expect(result.interrupted?).to be(false)
        expect(result.executed?).to be(true)
      end

      it "maintains state consistency for successful tasks" do
        result = state_tracking_task.call

        expect(result.state).to eq("complete")
        expect(result.complete?).to be(true)
        expect(result.executed?).to be(true)
        expect(result.context.business_logic_executed).to be(true)
      end
    end

    context "with interrupted execution states" do
      it "tracks state transitions for failed tasks" do
        result = interrupting_task.call

        expect(result.initialized?).to be(false)
        expect(result.executing?).to be(false)
        expect(result.complete?).to be(false)
        expect(result.interrupted?).to be(true)
        expect(result.executed?).to be(true)
      end

      it "tracks state transitions for skipped tasks" do
        result = skipping_task.call

        expect(result.initialized?).to be(false)
        expect(result.executing?).to be(false)
        expect(result.complete?).to be(false)
        expect(result.interrupted?).to be(true)
        expect(result.executed?).to be(true)
      end
    end

    context "with state-based callbacks" do
      let(:callback_tracking_task) do
        Class.new(CMDx::Task) do
          def call
            context.main_work_done = true
          end
        end
      end

      it "executes state-based callbacks for successful completion" do
        callback_results = []

        result = callback_tracking_task.call
        result
          .on_complete { |r| callback_results << [:complete, r.context.main_work_done] }
          .on_interrupted { |r| callback_results << [:interrupted, r] }
          .on_executed { |r| callback_results << [:executed, r.runtime] }

        expect(callback_results).to contain_exactly(
          [:complete, true],
          [:executed, result.runtime]
        )
      end

      it "executes state-based callbacks for interrupted tasks" do
        callback_results = []

        result = interrupting_task.call
        result
          .on_complete { |r| callback_results << [:complete, r] }
          .on_interrupted { |r| callback_results << [:interrupted, r.metadata[:reason]] }
          .on_executed { |r| callback_results << [:executed, r.state] }

        expect(callback_results).to contain_exactly(
          [:interrupted, "Validation failed"],
          [:executed, "interrupted"]
        )
      end

      it "chains state callbacks fluently" do
        callback_sequence = []

        result = callback_tracking_task.call
        final_result = result
                       .on_complete { |_r| callback_sequence << :complete }
                       .on_executed { |_r| callback_sequence << :executed }

        expect(final_result).to eq(result)
        expect(callback_sequence).to eq(%i[complete executed])
      end
    end

    context "with state vs status distinction" do
      it "distinguishes between state and status for successful tasks" do
        result = state_tracking_task.call

        # State indicates WHERE in lifecycle
        expect(result.state).to eq("complete")
        # Status indicates HOW execution ended
        expect(result.status).to eq("success")
      end

      it "distinguishes between state and status for failed tasks" do
        result = interrupting_task.call

        # State indicates WHERE in lifecycle
        expect(result.state).to eq("interrupted")
        # Status indicates HOW execution ended
        expect(result.status).to eq("failed")
      end

      it "distinguishes between state and status for skipped tasks" do
        result = skipping_task.call

        # State indicates WHERE in lifecycle
        expect(result.state).to eq("interrupted")
        # Status indicates HOW execution ended
        expect(result.status).to eq("skipped")
      end
    end
  end

  describe "Statuses and Execution Outcomes" do
    let(:successful_order_task) do
      Class.new(CMDx::Task) do
        required :order_id, type: :integer

        def call
          context.order = { id: order_id, status: "completed" }
          context.notification_sent = true
        end
      end
    end

    let(:conditional_skip_task) do
      Class.new(CMDx::Task) do
        required :order_id, type: :integer

        def call
          order = { id: order_id, status: "already_processed" }

          if order[:status] == "already_processed"
            skip!(
              reason: "Order already processed",
              processed_at: Time.now - 3600,
              original_processor: "system",
              skip_code: "DUPLICATE_ORDER"
            )
          end

          context.order = order
        end
      end
    end

    let(:validation_failure_task) do
      Class.new(CMDx::Task) do
        required :email, type: :string

        def call
          unless email.include?("@")
            fail!(
              reason: "Invalid email format",
              errors: ["Email must contain @"],
              error_code: "VALIDATION_FAILED",
              retryable: false,
              failed_at: Time.now
            )
          end

          context.email_validated = true
        end
      end
    end

    context "with successful status outcomes" do
      it "tracks success status and provides predicates" do
        result = successful_order_task.call(order_id: 123)

        expect(result.success?).to be(true)
        expect(result.skipped?).to be(false)
        expect(result.failed?).to be(false)
        expect(result.good?).to be(true)
        expect(result.bad?).to be(false)
      end

      it "maintains success status with minimal metadata" do
        result = successful_order_task.call(order_id: 456)

        expect(result.status).to eq("success")
        expect(result.metadata).to be_empty
        expect(result.context.order[:status]).to eq("completed")
        expect(result.context.notification_sent).to be(true)
      end
    end

    context "with skipped status outcomes" do
      it "tracks skipped status and provides rich metadata" do
        result = conditional_skip_task.call(order_id: 789)

        expect(result.success?).to be(false)
        expect(result.skipped?).to be(true)
        expect(result.failed?).to be(false)
        expect(result.good?).to be(true)
        expect(result.bad?).to be(true)
      end

      it "preserves detailed skip metadata" do
        result = conditional_skip_task.call(order_id: 101)

        expect(result.status).to eq("skipped")
        expect(result.metadata[:reason]).to eq("Order already processed")
        expect(result.metadata[:processed_at]).to be_a(Time)
        expect(result.metadata[:original_processor]).to eq("system")
        expect(result.metadata[:skip_code]).to eq("DUPLICATE_ORDER")
      end
    end

    context "with failed status outcomes" do
      it "tracks failed status and provides predicates" do
        result = validation_failure_task.call(email: "invalid-email")

        expect(result.success?).to be(false)
        expect(result.skipped?).to be(false)
        expect(result.failed?).to be(true)
        expect(result.good?).to be(false)
        expect(result.bad?).to be(true)
      end

      it "preserves comprehensive failure metadata" do
        result = validation_failure_task.call(email: "bad-format")

        expect(result.status).to eq("failed")
        expect(result.metadata[:reason]).to eq("Invalid email format")
        expect(result.metadata[:errors]).to eq(["Email must contain @"])
        expect(result.metadata[:error_code]).to eq("VALIDATION_FAILED")
        expect(result.metadata[:retryable]).to be(false)
        expect(result.metadata[:failed_at]).to be_a(Time)
      end
    end

    context "with status-based callbacks" do
      let(:callback_order_task) do
        Class.new(CMDx::Task) do
          def call
            context.order_processed = true
          end
        end
      end

      it "executes status-based callbacks for successful outcomes" do
        callback_results = []

        result = callback_order_task.call
        result
          .on_success { |r| callback_results << [:success, r.context.order_processed] }
          .on_skipped { |r| callback_results << [:skipped, r.metadata[:reason]] }
          .on_failed { |r| callback_results << [:failed, r.metadata[:error_code]] }
          .on_good { |r| callback_results << [:good, r.status] }
          .on_bad { |r| callback_results << [:bad, r.status] }

        expect(callback_results).to contain_exactly(
          [:success, true],
          [:good, "success"]
        )
      end

      it "executes status-based callbacks for skipped outcomes" do
        callback_results = []

        result = conditional_skip_task.call(order_id: 202)
        result
          .on_success { |r| callback_results << [:success, r] }
          .on_skipped { |r| callback_results << [:skipped, r.metadata[:skip_code]] }
          .on_failed { |r| callback_results << [:failed, r] }
          .on_good { |r| callback_results << [:good, r.status] }
          .on_bad { |r| callback_results << [:bad, r.status] }

        expect(callback_results).to contain_exactly(
          [:skipped, "DUPLICATE_ORDER"],
          [:good, "skipped"],
          [:bad, "skipped"]
        )
      end

      it "executes status-based callbacks for failed outcomes" do
        callback_results = []

        result = validation_failure_task.call(email: "no-at-sign")
        result
          .on_success { |r| callback_results << [:success, r] }
          .on_skipped { |r| callback_results << [:skipped, r] }
          .on_failed { |r| callback_results << [:failed, r.metadata[:error_code]] }
          .on_good { |r| callback_results << [:good, r] }
          .on_bad { |r| callback_results << [:bad, r.status] }

        expect(callback_results).to contain_exactly(
          [:failed, "VALIDATION_FAILED"],
          [:bad, "failed"]
        )
      end
    end

    context "with outcome-based decision making" do
      it "supports good vs bad outcome logic" do
        # Define tasks locally to avoid scope issues
        successful_task = Class.new(CMDx::Task) do
          required :order_id, type: :integer
          def call
            context.order = { id: order_id, status: "completed" }
            context.notification_sent = true
          end
        end

        skip_task = Class.new(CMDx::Task) do
          required :order_id, type: :integer
          def call
            order = { id: order_id, status: "already_processed" }
            if order[:status] == "already_processed"
              skip!(
                reason: "Order already processed",
                processed_at: Time.now - 3600,
                original_processor: "system",
                skip_code: "DUPLICATE_ORDER"
              )
            end
            context.order = order
          end
        end

        fail_task = Class.new(CMDx::Task) do
          required :email, type: :string
          def call
            unless email.include?("@")
              fail!(
                reason: "Invalid email format",
                errors: ["Email must contain @"],
                error_code: "VALIDATION_FAILED",
                retryable: false,
                failed_at: Time.now
              )
            end
            context.email_validated = true
          end
        end

        successful_result = successful_task.call(order_id: 111)
        skipped_result = skip_task.call(order_id: 222)
        failed_result = fail_task.call(email: "bad")

        # Good outcomes (success OR skipped)
        expect(successful_result.good?).to be(true)
        expect(skipped_result.good?).to be(true)
        expect(failed_result.good?).to be(false)

        # Bad outcomes (not success - includes skipped and failed)
        expect(successful_result.bad?).to be(false)
        expect(skipped_result.bad?).to be(true)
        expect(failed_result.bad?).to be(true)
      end

      it "enables status-based conditional logic" do
        results = [
          successful_order_task.call(order_id: 333),
          conditional_skip_task.call(order_id: 444),
          validation_failure_task.call(email: "invalid")
        ]

        outcomes = results.map do |result|
          case result.status
          when "success"
            { type: :success, data: result.context.to_h }
          when "skipped"
            { type: :skipped, reason: result.metadata[:reason] }
          when "failed"
            { type: :failed, error: result.metadata[:error_code] }
          end
        end

        expect(outcomes).to contain_exactly(
          { type: :success, data: hash_including(order_id: 333) },
          { type: :skipped, reason: "Order already processed" },
          { type: :failed, error: "VALIDATION_FAILED" }
        )
      end
    end
  end

  describe "Failure Chain Analysis" do
    let(:root_cause_task) do
      Class.new(CMDx::Task) do
        def call
          fail!(
            reason: "Database connection failed",
            error_code: "DB_CONNECTION_ERROR",
            retryable: true
          )
        end
      end
    end

    let(:propagating_task) do
      Class.new(CMDx::Task) do
        def call
          # Define the root cause task inline
          root_cause_task = Class.new(CMDx::Task) do
            def call
              fail!(
                reason: "Database connection failed",
                error_code: "DB_CONNECTION_ERROR",
                connection_timeout: 30
              )
            end
          end

          child_result = root_cause_task.call

          return unless child_result.failed?

          throw!(child_result, parent_context: "During user registration")
        end
      end
    end

    let(:complex_workflow_task) do
      Class.new(CMDx::Task) do
        def call
          validation_task = Class.new(CMDx::Task) do
            required :email, type: :string
            def call
              unless email.include?("@")
                fail!(
                  reason: "Invalid email format",
                  errors: ["Email must contain @"],
                  error_code: "VALIDATION_FAILED",
                  retryable: false,
                  failed_at: Time.now
                )
              end
              context.email_validated = true
            end
          end

          validation_result = validation_task.call(email: "invalid")

          return unless validation_result.failed?

          throw!(validation_result, workflow_step: "email_validation")
        end
      end
    end

    context "with failure chain tracking" do
      it "identifies original failure causes" do
        result = propagating_task.call

        expect(result).to be_failed
        expect(result.caused_failure?).to be(false)
        expect(result.thrown_failure?).to be(true)

        original_failure = result.caused_failure
        expect(original_failure).to be_a(CMDx::Result)
        expect(original_failure.caused_failure?).to be(true)
        expect(original_failure.metadata[:reason]).to eq("Database connection failed")
        expect(original_failure.metadata[:error_code]).to eq("DB_CONNECTION_ERROR")
      end

      it "tracks failure propagation chain" do
        result = propagating_task.call

        expect(result.threw_failure?).to be(false)
        expect(result.thrown_failure?).to be(true)

        throwing_task = result.threw_failure
        expect(throwing_task).to be_a(CMDx::Result)
        expect(throwing_task.caused_failure?).to be(true)
      end

      it "provides comprehensive failure chain serialization" do
        result = propagating_task.call

        serialized = result.to_h
        expect(serialized).to include(:caused_failure, :threw_failure)

        caused_failure = serialized[:caused_failure]
        expect(caused_failure).to include(
          state: "interrupted",
          status: "failed"
        )

        threw_failure = serialized[:threw_failure]
        expect(threw_failure).to include(
          state: "interrupted",
          status: "failed"
        )
      end
    end

    context "with nested failure scenarios" do
      it "handles complex failure chain analysis" do
        result = complex_workflow_task.call

        expect(result).to be_failed
        expect(result.caused_failure?).to be(false)
        expect(result.thrown_failure?).to be(true)

        # Find the root cause
        original_failure = result.caused_failure
        expect(original_failure.metadata[:reason]).to eq("Invalid email format")
        expect(original_failure.metadata[:error_code]).to eq("VALIDATION_FAILED")

        # Verify the propagation
        expect(result.metadata[:workflow_step]).to eq("email_validation")
      end
    end
  end

  describe "Pattern Matching and Advanced Operations" do
    let(:pattern_test_task) do
      Class.new(CMDx::Task) do
        required :outcome_type, type: :string

        def call
          case outcome_type
          when "success"
            context.result = "completed"
          when "skip"
            skip!(reason: "Skipped by design", design_pattern: "guard_clause")
          when "fail"
            fail!(reason: "Intentional failure", test_mode: true)
          end
        end
      end
    end

    context "with pattern matching support" do
      it "supports array pattern matching" do
        results = [
          pattern_test_task.call(outcome_type: "success"),
          pattern_test_task.call(outcome_type: "skip"),
          pattern_test_task.call(outcome_type: "fail")
        ]

        patterns = results.map do |result|
          case result
          in ["complete", "success"]
            :successful_completion
          in ["interrupted", "skipped"]
            :skipped_completion
          in ["interrupted", "failed"]
            :failed_execution
          end
        end

        expect(patterns).to eq(%i[
                                 successful_completion
                                 skipped_completion
                                 failed_execution
                               ])
      end

      it "supports hash pattern matching with metadata" do
        results = [
          pattern_test_task.call(outcome_type: "skip"),
          pattern_test_task.call(outcome_type: "fail")
        ]

        pattern_results = results.map do |result|
          case result
          in { state: "interrupted", status: "skipped", metadata: { reason: String => reason } }
            { type: :skip, reason: reason }
          in { state: "interrupted", status: "failed", metadata: { test_mode: true } }
            { type: :test_failure, metadata: result.metadata }
          end
        end

        expect(pattern_results).to contain_exactly(
          { type: :skip, reason: "Skipped by design" },
          { type: :test_failure, metadata: hash_including(test_mode: true) }
        )
      end
    end

    context "with conditional result processing" do
      it "enables advanced conditional logic" do
        # Define tasks locally to avoid scope issues
        successful_task = Class.new(CMDx::Task) do
          required :order_id, type: :integer
          def call
            context.order = { id: order_id, status: "completed" }
            context.notification_sent = true
          end
        end

        skip_task = Class.new(CMDx::Task) do
          required :order_id, type: :integer
          def call
            order = { id: order_id, status: "already_processed" }
            if order[:status] == "already_processed"
              skip!(
                reason: "Order already processed",
                processed_at: Time.now - 3600,
                original_processor: "system",
                skip_code: "DUPLICATE_ORDER"
              )
            end
            context.order = order
          end
        end

        fail_task = Class.new(CMDx::Task) do
          required :email, type: :string
          def call
            unless email.include?("@")
              fail!(
                reason: "Invalid email format",
                errors: ["Email must contain @"],
                error_code: "VALIDATION_FAILED",
                retryable: false,
                failed_at: Time.now
              )
            end
            context.email_validated = true
          end
        end

        results = [
          successful_task.call(order_id: 501),
          skip_task.call(order_id: 502),
          fail_task.call(email: "test")
        ]

        processed_results = results.map do |result|
          case result
          in { executed: true, good: true, status: "success" }
            { outcome: :success, data: result.context.to_h }
          in { executed: true, good: true, status: "skipped" }
            { outcome: :skipped, reason: result.metadata[:reason] }
          in { executed: true, bad: true, status: "failed" }
            { outcome: :failed, error: result.metadata[:error_code] }
          end
        end

        expect(processed_results).to contain_exactly(
          { outcome: :success, data: hash_including(order_id: 501) },
          { outcome: :skipped, reason: "Order already processed" },
          { outcome: :failed, error: "VALIDATION_FAILED" }
        )
      end
    end
  end

  describe "Outcome Integration with Other Components" do
    let(:chain_analysis_task) do
      Class.new(CMDx::Task) do
        def call
          # Simulate subtask execution
          subtask_task = Class.new(CMDx::Task) do
            required :order_id, type: :integer
            def call
              context.order = { id: order_id, status: "completed" }
              context.notification_sent = true
            end
          end
          subtask_result = subtask_task.call(order_id: 999)
          context.subtask_executed = true
          context.subtask_result = subtask_result.to_h
        end
      end
    end

    let(:context_sharing_task) do
      Class.new(CMDx::Task) do
        required :shared_data, type: :hash

        def call
          context.merge!(shared_data)
          context.processing_complete = true
        end
      end
    end

    context "with context integration" do
      it "maintains context accessibility through results" do
        shared_data = { user_id: 123, session_id: "abc123" }
        result = context_sharing_task.call(shared_data: shared_data)

        expect(result.context.user_id).to eq(123)
        expect(result.context.session_id).to eq("abc123")
        expect(result.context.processing_complete).to be(true)
      end

      it "preserves context state across task execution" do
        result = chain_analysis_task.call

        expect(result.context.subtask_executed).to be(true)
        expect(result.context.subtask_result).to be_a(Hash)
        expect(result.context.subtask_result[:status]).to eq("success")
      end
    end

    context "with chain integration" do
      it "maintains chain relationship through results" do
        order_task = Class.new(CMDx::Task) do
          required :order_id, type: :integer
          def call
            context.order = { id: order_id, status: "completed" }
            context.notification_sent = true
          end
        end
        result = order_task.call(order_id: 777)

        expect(result.chain).to be_a(CMDx::Chain)
        expect(result.chain.to_h[:id]).to be_a(String)
        expect(result.chain.results).to include(result)
        expect(result.chain.state).to eq(result.state)
        expect(result.chain.status).to eq(result.status)
      end

      it "provides chain-level outcome aggregation" do
        result = chain_analysis_task.call

        chain_data = result.chain.to_h
        expect(chain_data).to include(
          state: "complete",
          status: "success",
          results: array_including(hash_including(status: "success"))
        )
        expect(chain_data[:id]).to be_a(String)
      end
    end

    context "with task instance integration" do
      it "maintains task instance relationship" do
        order_task = Class.new(CMDx::Task) do
          required :order_id, type: :integer
          def call
            context.order = { id: order_id, status: "completed" }
            context.notification_sent = true
          end
        end
        result = order_task.call(order_id: 888)

        expect(result.task).to be_a(order_task)
        expect(result.task.id).to be_a(String)
        expect(result.task.context).to eq(result.context)
        expect(result.task.result).to eq(result)
      end
    end
  end
end
