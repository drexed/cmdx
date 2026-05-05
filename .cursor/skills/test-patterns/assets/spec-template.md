# Spec Templates

## Unit Spec (class/module under test)

```ruby
# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ClassName do
  subject(:instance) { described_class.new(args) }

  let(:args) { {} }

  describe ".class_method" do
    context "when condition" do
      it "returns expected" do
        expect(described_class.class_method).to eq(expected)
      end
    end
  end

  describe "#instance_method" do
    context "when condition" do
      it "returns expected" do
        expect(instance.instance_method).to eq(expected)
      end
    end

    context "with invalid input" do
      it "raises error" do
        expect { instance.instance_method(bad) }.to raise_error(ArgumentError)
      end
    end
  end
end
```

## Integration Spec (task execution)

```ruby
# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Feature name", type: :feature do
  context "when soft execution" do
    subject(:result) { task.execute }

    context "when successful" do
      let(:task) { create_successful_task }

      it "returns success" do
        expect(result).to have_attributes(
          state: CMDx::Signal::COMPLETE,
          status: CMDx::Signal::SUCCESS,
          reason: nil,
          metadata: {},
          cause: nil
        )
        expect(result.context).to have_attributes(
          executed: %i[success]
        )
      end
    end

    context "when failing" do
      let(:task) { create_failing_task(reason: "something broke") }

      it "returns failure" do
        expect(result).to have_attributes(
          state: CMDx::Signal::INTERRUPTED,
          status: CMDx::Signal::FAILED,
          reason: "something broke"
        )
      end
    end
  end

  context "when bang execution" do
    subject(:result) { task.execute! }

    context "when failing" do
      let(:task) { create_failing_task(reason: "something broke") }

      it "raises fault" do
        expect { result }.to raise_error(CMDx::FailFault, "something broke")
      end
    end
  end
end
```

## Integration Spec (workflow execution)

```ruby
# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Workflow feature name", type: :feature do
  context "when non-blocking" do
    subject(:result) { workflow.execute }

    context "when successful" do
      let(:workflow) { create_successful_workflow }

      it "returns success" do
        expect(result).to be_successful
        expect(result).to have_matching_context(executed: %i[success inner middle outer success])
      end
    end
  end

  context "when blocking" do
    subject(:result) { workflow.execute! }

    context "when failing" do
      let(:workflow) { create_failing_workflow }

      it "raises fault" do
        expect { result }.to raise_error(CMDx::FailFault)
      end
    end
  end
end
```

## Integration Spec (workflow with inline DSL)

```ruby
# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Workflow feature name", type: :feature do
  context "when using custom configuration" do
    it "applies settings to execution" do
      task1 = create_successful_task(name: "Task1")
      task2 = create_successful_task(name: "Task2")

      workflow = create_workflow_class do
        settings(workflow_breakpoints: [])

        task task1
        task task2
      end

      result = workflow.new.execute

      expect(result).to be_successful
      expect(result.chain.results.size).to eq(3)
    end
  end

  context "when using conditionals" do
    it "evaluates condition at runtime" do
      task1 = create_successful_task(name: "Task1")

      workflow = create_workflow_class do
        task task1, if: proc { context.enabled == true }
      end

      enabled_result = workflow.execute(enabled: true)
      disabled_result = workflow.execute(enabled: false)

      expect(enabled_result.chain.results.size).to eq(2)
      expect(disabled_result.chain.results.size).to eq(1)
    end
  end
end
```
