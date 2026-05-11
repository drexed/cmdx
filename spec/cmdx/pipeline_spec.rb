# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Pipeline do
  after { CMDx::Chain.clear }

  describe ".execute" do
    it "delegates to a new Pipeline instance" do
      workflow_instance = create_workflow_class.new
      pipeline = instance_double(described_class)
      expect(described_class).to receive(:new).with(workflow_instance).and_return(pipeline)
      expect(pipeline).to receive(:execute)

      described_class.execute(workflow_instance)
    end
  end

  describe "#execute" do
    context "with an empty pipeline" do
      it "is a no-op" do
        workflow_class = create_workflow_class
        result = workflow_class.execute

        expect(result).to be_success
        expect(result.chain.size).to eq(1)
      end
    end

    context "when a group has no tasks" do
      it "is a silent no-op (declaration-time validation prevents this in normal use)" do
        workflow_class = create_workflow_class
        workflow_class.pipeline << CMDx::Workflow::ExecutionGroup.new(tasks: [], options: {})

        expect(workflow_class.execute).to be_success
      end
    end

    context "with an invalid strategy" do
      it "propagates ArgumentError via execute!" do
        task = create_successful_task
        workflow_class = create_workflow_class do
          tasks task, strategy: :bogus
        end

        expect { workflow_class.execute! }.to raise_error(ArgumentError, /invalid pipeline strategy :bogus/)
      end
    end

    context "with :if guard" do
      it "skips the group when the guard is false" do
        task = create_failing_task(reason: "should not run")
        workflow_class = create_workflow_class do
          tasks task, if: proc { false }
        end

        expect(workflow_class.execute).to be_success
      end

      it "runs the group when the guard is true" do
        task = create_successful_task
        workflow_class = create_workflow_class do
          tasks task, if: proc { true }
        end

        expect(workflow_class.execute).to be_success
      end
    end

    context "with :unless guard" do
      it "skips the group when the guard is true" do
        task = create_failing_task(reason: "should not run")
        workflow_class = create_workflow_class do
          tasks task, unless: proc { true }
        end

        expect(workflow_class.execute).to be_success
      end
    end

    describe "continue_on_failure aggregation" do
      let(:input_validation_task) do
        klass = Class.new(CMDx::Task)
        klass.define_singleton_method(:name) { "ValidatesAmount" }
        klass.required(:amount)
        klass.define_method(:work) { context.executed_validation = true }
        klass
      end

      let(:bare_failing_task) do
        klass = Class.new(CMDx::Task)
        klass.define_singleton_method(:name) { "BareFailer" }
        klass.define_method(:work) { fail!("bare boom") }
        klass
      end

      let(:reasonless_failing_task) do
        klass = Class.new(CMDx::Task)
        klass.define_singleton_method(:name) { "Reasonless" }
        klass.define_method(:work) { fail! }
        klass
      end

      let(:succeeding_task) do
        klass = Class.new(CMDx::Task)
        klass.define_singleton_method(:name) { "Winner" }
        klass.define_method(:work) { context.winner_ran = true }
        klass
      end

      describe "sequential" do
        it "runs every task and aggregates failures into result.errors" do
          a = bare_failing_task
          b = input_validation_task
          c = succeeding_task

          workflow_class = create_workflow_class do
            tasks a, b, c, continue_on_failure: true
          end

          result = workflow_class.execute

          expect(result).to be_failed
          expect(result.context[:winner_ran]).to be(true)
          expect(result.errors[:"BareFailer.failed"]).to eq(["bare boom"])
          expect(result.errors[:"ValidatesAmount.amount"]).to eq([CMDx::I18nProxy.t("cmdx.attributes.required")])
        end

        it "uses the localized unspecified message when fail! has no reason" do
          a = reasonless_failing_task

          workflow_class = create_workflow_class do
            tasks a, continue_on_failure: true
          end

          result = workflow_class.execute

          expect(result).to be_failed
          expect(result.errors[:"Reasonless.failed"]).to eq([CMDx::I18nProxy.t("cmdx.reasons.unspecified")])
        end

        it "resolves the failure reason through I18nProxy when a translation key matches" do
          allow(CMDx::I18nProxy).to receive(:tr).with("translatable.reason").and_return("Translated reason")
          a = create_failing_task(name: "Translatable", reason: "translatable.reason")

          workflow_class = create_workflow_class do
            tasks a, continue_on_failure: true
          end

          result = workflow_class.execute

          expect(result).to be_failed
          translatable_key = result.errors.messages.keys.find { |k| k.to_s.start_with?("Translatable") }
          expect(result.errors[translatable_key]).to eq(["Translated reason"])
        end

        it "the first failure (declaration order) becomes the signal origin" do
          first_fail = create_failing_task(name: "First", reason: "first")
          second_fail = create_failing_task(name: "Second", reason: "second")

          workflow_class = create_workflow_class do
            tasks first_fail, second_fail, continue_on_failure: true
          end

          result = workflow_class.execute

          expect(result.reason).to eq("first")
        end

        it "halts the pipeline after the failed group (subsequent groups do not run)" do
          a = create_failing_task(name: "Halter", reason: "stop")
          after = create_task_class(name: "After") { define_method(:work) { context.after_ran = true } }

          workflow_class = create_workflow_class do
            tasks a, continue_on_failure: true
            task after
          end

          result = workflow_class.execute

          expect(result).to be_failed
          expect(result.context[:after_ran]).to be_nil
        end

        it "does not aggregate when continue_on_failure is false (default)" do
          a = create_failing_task(name: "OnlyFail", reason: "stop")
          b = create_successful_task(name: "Skipped")

          workflow_class = create_workflow_class do
            tasks a, b
          end

          result = workflow_class.execute

          expect(result).to be_failed
          expect(result.errors).to be_empty
        end
      end

      describe "parallel" do
        it "runs every task, merges successes, and aggregates failures" do
          ok_task = succeeding_task
          fail_task = bare_failing_task

          workflow_class = create_workflow_class do
            tasks ok_task, fail_task, strategy: :parallel, continue_on_failure: true
          end

          result = workflow_class.execute

          expect(result).to be_failed
          expect(result.context[:winner_ran]).to be(true)
          expect(result.errors[:"BareFailer.failed"]).to eq(["bare boom"])
        end
      end
    end

    describe "sequential strategy" do
      it "runs each task in order" do
        task1 = create_successful_task(name: "T1")
        task2 = create_successful_task(name: "T2")
        workflow_class = create_workflow_class do
          tasks task1, task2
        end

        result = workflow_class.execute
        expect(result.chain.map { |r| r.task.name }).to match([/AnonymousWorkflow/, /T1/, /T2/])
      end

      it "halts the group when a task fails" do
        task1 = create_failing_task(reason: "stop")
        task2 = create_successful_task(name: "NeverRun")
        workflow_class = create_workflow_class do
          tasks task1, task2
        end

        result = workflow_class.execute
        expect(result).to be_failed
        task_names = result.chain.map { |r| r.task.name }
        expect(task_names.any? { |n| n.include?("NeverRun") }).to be(false)
      end
    end

    describe "parallel strategy" do
      it "runs every task regardless of failure when continue_on_failure is true" do
        task1 = create_failing_task(name: "Failing1", reason: "f1")
        task2 = create_successful_task(name: "Succ2")
        task3 = create_successful_task(name: "Succ3")

        workflow_class = create_workflow_class do
          tasks task1, task2, task3, strategy: :parallel, continue_on_failure: true
        end

        result = workflow_class.execute

        expect(result).to be_failed
        task_names = result.chain.map { |r| r.task.name }
        expect(task_names.count { |n| n.include?("Succ2") }).to eq(1)
        expect(task_names.count { |n| n.include?("Succ3") }).to eq(1)
      end

      it "respects :pool_size" do
        task1 = create_successful_task(name: "Par1")
        task2 = create_successful_task(name: "Par2")

        workflow_class = create_workflow_class do
          tasks task1, task2, strategy: :parallel, pool_size: 1
        end

        expect(workflow_class.execute).to be_success
      end

      describe ":continue_on_failure" do
        it "skips queued tasks after the first failure by default (pool_size: 1)" do
          failing = create_failing_task(name: "First", reason: "stop")
          never_run = create_task_class(name: "NeverRun") do
            define_method(:work) { context.ran = true }
          end

          workflow_class = create_workflow_class do
            tasks failing, never_run, strategy: :parallel, pool_size: 1
          end

          result = workflow_class.execute
          expect(result).to be_failed
          expect(result.reason).to eq("stop")
          expect(result.context[:ran]).to be_nil
          task_names = result.chain.map { |r| r.task.name }
          expect(task_names.any? { |n| n.include?("NeverRun") }).to be(false)
        end

        it "runs every task when continue_on_failure is true" do
          failing = create_failing_task(name: "First", reason: "stop")
          other = create_task_class(name: "Other") do
            define_method(:work) { context.ran = true }
          end

          workflow_class = create_workflow_class do
            tasks failing, other, strategy: :parallel, pool_size: 1, continue_on_failure: true
          end

          result = workflow_class.execute
          expect(result).to be_failed
          expect(result.context[:ran]).to be(true)
        end

        it "runs with executor: :threads (explicit, same as default)" do
          t1 = create_successful_task(name: "E1")
          t2 = create_successful_task(name: "E2")
          workflow_class = create_workflow_class do
            tasks t1, t2, strategy: :parallel, executor: :threads
          end

          expect(workflow_class.execute).to be_success
        end

        it "runs with a callable executor override" do
          t1 = create_successful_task(name: "C1")
          t2 = create_successful_task(name: "C2")
          calls = []
          executor = lambda do |jobs:, concurrency:, on_job:|
            calls << [jobs.size, concurrency]
            jobs.each { |j| on_job.call(j) }
          end

          workflow_class = create_workflow_class do
            tasks(t1, t2, strategy: :parallel, executor:)
          end

          expect(workflow_class.execute).to be_success
          expect(calls).to eq([[2, 2]])
        end

        it "rejects an unknown executor symbol" do
          t1 = create_successful_task(name: "U1")
          workflow_class = create_workflow_class do
            tasks t1, strategy: :parallel, executor: :bogus
          end

          expect { workflow_class.execute! }.to raise_error(CMDx::UnknownEntryError, /unknown executor :bogus/)
        end

        it "raises when executor: :fibers has no Fiber.scheduler installed" do
          t1 = create_successful_task(name: "F1")
          workflow_class = create_workflow_class do
            tasks t1, strategy: :parallel, executor: :fibers
          end

          expect { workflow_class.execute! }.to raise_error(RuntimeError, /Fiber\.scheduler/)
        end

        it "runs tasks via executor: :fibers when a Fiber.scheduler is installed" do
          scheduler = Class.new do
            def fiber(&block)
              fiber = Fiber.new(blocking: false, &block)
              fiber.resume
              fiber
            end

            def close; end
            def block(*); end
            def unblock(*); end
            def kernel_sleep(*); end
            def io_wait(*); end
            def process_wait(*); end
            def fiber_interrupt(*); end
          end.new

          t1 = create_task_class(name: "F1") { define_method(:work) { context.a = true } }
          t2 = create_task_class(name: "F2") { define_method(:work) { context.b = true } }
          workflow_class = create_workflow_class do
            tasks t1, t2, strategy: :parallel, executor: :fibers
          end

          result = nil
          Thread.new do
            Fiber.set_scheduler(scheduler)
            result = workflow_class.execute
          ensure
            Fiber.set_scheduler(nil)
          end.join

          expect(result).to be_success
          expect(result.context.a).to be(true)
          expect(result.context.b).to be(true)
        end

        it "merges context from tasks that completed before the failure was observed" do
          ok = create_task_class(name: "Ok") do
            define_method(:work) { context.ok = true }
          end
          failing = create_failing_task(name: "Fail", reason: "boom")
          never_run = create_task_class(name: "NeverRun") do
            define_method(:work) { context.ran = true }
          end

          workflow_class = create_workflow_class do
            tasks ok, failing, never_run, strategy: :parallel, pool_size: 1
          end

          result = workflow_class.execute
          expect(result).to be_failed
          expect(result.context[:ok]).to be(true)
          expect(result.context[:ran]).to be_nil
        end
      end

      describe ":merger" do
        let(:writer_a) do
          create_task_class(name: "WA") do
            define_method(:work) do
              context.a = 1
              context.nested = { a: 1, shared: "a" }
            end
          end
        end
        let(:writer_b) do
          create_task_class(name: "WB") do
            define_method(:work) do
              context.b = 2
              context.nested = { b: 2, shared: "b" }
            end
          end
        end

        it "defaults to :last_write_wins (shallow, later-declared wins on conflict)" do
          wa = writer_a
          wb = writer_b
          workflow_class = create_workflow_class do
            tasks wa, wb, strategy: :parallel
          end

          result = workflow_class.execute
          expect(result.context.a).to eq(1)
          expect(result.context.b).to eq(2)
          expect(result.context.nested).to eq({ b: 2, shared: "b" })
        end

        it "recursively merges nested hashes under :deep_merge" do
          wa = writer_a
          wb = writer_b
          workflow_class = create_workflow_class do
            tasks wa, wb, strategy: :parallel, merger: :deep_merge
          end

          result = workflow_class.execute
          expect(result.context.nested).to eq({ a: 1, b: 2, shared: "b" })
        end

        it "leaves the workflow context untouched under :no_merge" do
          wa = writer_a
          wb = writer_b
          workflow_class = create_workflow_class do
            tasks wa, wb, strategy: :parallel, merger: :no_merge
          end

          result = workflow_class.execute
          expect(result).to be_success
          expect(result.context.a).to be_nil
          expect(result.context.b).to be_nil
          expect(result.context.nested).to be_nil
        end

        it "accepts a callable merger" do
          wa = writer_a
          wb = writer_b
          seen = []
          collector = lambda { |ctx, result|
            seen << result
            ctx.merge_count = (ctx.merge_count || 0) + 1
          }

          workflow_class = create_workflow_class do
            tasks wa, wb, strategy: :parallel, merger: collector
          end

          result = workflow_class.execute
          expect(result.context.merge_count).to eq(2)
          expect(seen.map(&:task)).to contain_exactly(wa, wb)
        end

        it "rejects unknown symbols" do
          wa = writer_a
          workflow_class = create_workflow_class do
            tasks wa, strategy: :parallel, merger: :bogus
          end

          expect { workflow_class.execute! }.to raise_error(CMDx::UnknownEntryError, /unknown merger :bogus/)
        end
      end

      describe "registry-based resolution" do
        it "resolves executors registered on the workflow class" do
          custom = ->(jobs:, on_job:, **) { jobs.each { |j| on_job.call(j) } }
          t1 = create_successful_task(name: "R1")
          workflow_class = create_workflow_class do
            register :executor, :inline, custom
            tasks t1, strategy: :parallel, executor: :inline
          end

          expect(workflow_class.execute).to be_success
        end

        it "resolves mergers registered on the workflow class" do
          seen = []
          collector = ->(_ctx, result) { seen << result }
          t1 = create_successful_task(name: "M1")
          workflow_class = create_workflow_class do
            register :merger, :collector, collector
            tasks t1, strategy: :parallel, merger: :collector
          end

          expect(workflow_class.execute).to be_success
          expect(seen.size).to eq(1)
        end
      end
    end
  end
end
