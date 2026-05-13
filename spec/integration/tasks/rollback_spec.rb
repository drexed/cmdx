# frozen_string_literal: true

RSpec.describe "Task rollback", type: :feature do
  describe "#rollback runs on failure" do
    context "when fail! was called" do
      it "invokes rollback and marks the result as rolled back" do
        task = create_failing_task(reason: "boom") do
          define_method(:rollback) { (context.log ||= []) << :rolled }
        end

        result = task.execute

        expect(result).to have_attributes(
          status: CMDx::Signal::FAILED,
          rolled_back?: true
        )
        expect(result.context[:log]).to eq(%i[rolled])
      end
    end

    context "when an exception was raised" do
      it "invokes rollback and marks the result as rolled back" do
        task = create_erroring_task do
          define_method(:rollback) { (context.log ||= []) << :rolled }
        end

        result = task.execute

        expect(result).to have_attributes(
          status: CMDx::Signal::FAILED,
          rolled_back?: true,
          cause: be_a(CMDx::TestError)
        )
        expect(result.context[:log]).to eq(%i[rolled])
      end
    end
  end

  describe "#rollback is skipped on success or skip" do
    it "does not run for a successful task" do
      task = create_successful_task do
        define_method(:rollback) { context.rolled = true }
      end

      expect(task.execute).to have_attributes(rolled_back?: false)
    end

    it "does not run for a skipped task" do
      task = create_skipping_task do
        define_method(:rollback) { context.rolled = true }
      end

      result = task.execute

      expect(result).to have_attributes(status: CMDx::Signal::SKIPPED, rolled_back?: false)
      expect(result.context).not_to respond_to(:rolled)
    end
  end

  describe "rollback ordering" do
    it "runs before on_failed and on_ko callbacks" do
      task = create_failing_task(reason: "boom") do
        on_failed { (context.log ||= []) << :on_failed }
        on_ko { (context.log ||= []) << :on_ko }
        define_method(:rollback) { (context.log ||= []) << :rollback }
      end

      expect(task.execute.context[:log]).to eq(%i[rollback on_failed on_ko])
    end
  end

  describe "without a #rollback method" do
    it "does not mark the result as rolled back" do
      expect(create_failing_task.execute).to have_attributes(rolled_back?: false)
    end
  end

  describe "blocking execute!" do
    it "runs rollback before raising the Fault for fail!" do
      log = []
      task = create_failing_task(reason: "boom") do
        define_method(:rollback) { log << :rolled }
      end

      expect { task.execute! }.to raise_error(CMDx::Fault, "boom")
      expect(log).to eq(%i[rolled])
    end

    it "runs rollback before raising the original exception" do
      log = []
      task = create_erroring_task(reason: "kaboom") do
        define_method(:rollback) { log << :rolled }
      end

      expect { task.execute! }.to raise_error(CMDx::TestError, "kaboom")
      expect(log).to eq(%i[rolled])
    end
  end
end
