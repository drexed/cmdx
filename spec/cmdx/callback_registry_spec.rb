# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::CallbackRegistry, type: :unit do
  subject(:registry) { described_class.new(initial_registry) }

  let(:initial_registry) { {} }
  let(:mock_task) { instance_double(CMDx::Task) }
  let(:callable_proc) { proc { |task| } }
  let(:callable_symbol) { :some_method }
  let(:callable_object) { instance_double("MockCallable", call: nil) }

  describe "#initialize" do
    context "when no registry is provided" do
      subject(:registry) { described_class.new }

      it "initializes with an empty hash" do
        expect(registry.registry).to eq({})
      end
    end

    context "when a registry is provided" do
      let(:initial_registry) { { before_execution: Set.new } }

      it "initializes with the provided registry" do
        expect(registry.registry).to eq(initial_registry)
      end
    end
  end

  describe "#registry" do
    it "returns the internal registry" do
      expect(registry.registry).to eq(initial_registry)
    end
  end

  describe "#to_h" do
    it "aliases the registry method" do
      expect(registry.to_h).to eq(registry.registry)
    end
  end

  describe "#dup" do
    context "when registry has values" do
      let(:initial_registry) do
        {
          before_execution: Set.new([[callable_proc], {}]),
          on_success: Set.new([[callable_symbol], { if: :success? }])
        }
      end

      it "returns a new instance" do
        duplicated = registry.dup

        expect(duplicated).not_to be(registry)
        expect(duplicated).to be_a(described_class)
      end

      it "deep copies the registry values" do
        duplicated = registry.dup

        expect(duplicated.registry).to eq(registry.registry)
        expect(duplicated.registry).not_to be(registry.registry)
        expect(duplicated.registry[:before_execution]).not_to be(registry.registry[:before_execution])
      end
    end

    context "when registry is empty" do
      let(:initial_registry) { {} }

      it "returns a new instance with empty registry" do
        duplicated = registry.dup

        expect(duplicated.registry).to eq({})
        expect(duplicated.registry).not_to be(registry.registry)
      end
    end
  end

  describe "#register" do
    it "returns self for method chaining" do
      result = registry.register(:before_execution, callable_proc)

      expect(result).to be(registry)
    end

    context "when registering a single callable" do
      it "adds the callable to the registry" do
        registry.register(:before_execution, callable_proc)

        expect(registry.registry[:before_execution]).to be_a(Set)
        expect(registry.registry[:before_execution]).to include([[callable_proc], {}])
      end
    end

    context "when registering multiple callables" do
      it "adds all callables as a single entry" do
        registry.register(:before_execution, callable_proc, callable_symbol)

        expect(registry.registry[:before_execution]).to include([[callable_proc, callable_symbol], {}])
      end
    end

    context "when registering with options" do
      let(:options) { { if: :active?, unless: :disabled? } }

      it "stores the options with the callables" do
        registry.register(:before_execution, callable_proc, **options)

        expect(registry.registry[:before_execution]).to include([[callable_proc], options])
      end
    end

    context "when registering with a block" do
      it "adds the block to the callables list" do
        block = proc { |task| task.blocked = true }
        registry.register(:before_execution, callable_proc, &block)

        expect(registry.registry[:before_execution]).to include([[callable_proc, block], {}])
      end
    end

    context "when registering to the same type multiple times" do
      it "accumulates callbacks in a Set" do
        registry.register(:before_execution, callable_proc)
        registry.register(:before_execution, callable_symbol)

        expect(registry.registry[:before_execution].size).to eq(2)
        expect(registry.registry[:before_execution]).to include([[callable_proc], {}])
        expect(registry.registry[:before_execution]).to include([[callable_symbol], {}])
      end
    end

    context "when registering the same callback twice" do
      it "stores only one copy due to Set behavior" do
        registry.register(:before_execution, callable_proc)
        registry.register(:before_execution, callable_proc)

        expect(registry.registry[:before_execution].size).to eq(1)
      end
    end
  end

  describe "#deregister" do
    it "returns self for method chaining" do
      registry.register(:before_execution, callable_proc)
      result = registry.deregister(:before_execution, callable_proc)

      expect(result).to be(registry)
    end

    context "when deregistering a single callable" do
      before do
        registry.register(:before_execution, callable_proc)
      end

      it "removes the callable from the registry" do
        registry.deregister(:before_execution, callable_proc)

        expect(registry.registry).not_to have_key(:before_execution)
      end
    end

    context "when deregistering multiple callables" do
      before do
        registry.register(:before_execution, callable_proc, callable_symbol)
      end

      it "removes the exact callables entry" do
        registry.deregister(:before_execution, callable_proc, callable_symbol)

        expect(registry.registry).not_to have_key(:before_execution)
      end
    end

    context "when deregistering with options" do
      let(:options) { { if: :active?, unless: :disabled? } }

      before do
        registry.register(:before_execution, callable_proc, **options)
      end

      it "removes only the entry with matching options" do
        registry.deregister(:before_execution, callable_proc, **options)

        expect(registry.registry).not_to have_key(:before_execution)
      end

      it "does not remove entries with different options" do
        registry.register(:before_execution, callable_proc, if: :other?)
        registry.deregister(:before_execution, callable_proc, **options)

        expect(registry.registry[:before_execution]).to include([[callable_proc], { if: :other? }])
      end
    end

    context "when deregistering with a block" do
      it "removes the entry with the block" do
        block = proc { |task| task.blocked = true }
        registry.register(:before_execution, callable_proc, &block)
        registry.deregister(:before_execution, callable_proc, &block)

        expect(registry.registry).not_to have_key(:before_execution)
      end
    end

    context "when deregistering from empty registry" do
      it "does not raise an error" do
        expect { registry.deregister(:before_execution, callable_proc) }.not_to raise_error
      end

      it "returns self" do
        result = registry.deregister(:before_execution, callable_proc)

        expect(result).to be(registry)
      end
    end

    context "when deregistering non-existent callback" do
      before do
        registry.register(:before_execution, callable_symbol)
      end

      it "does not affect existing callbacks" do
        registry.deregister(:before_execution, callable_proc)

        expect(registry.registry[:before_execution]).to include([[callable_symbol], {}])
      end
    end

    context "when deregistering from non-existent type" do
      it "does not raise an error" do
        expect { registry.deregister(:non_existent, callable_proc) }.not_to raise_error
      end

      it "returns self" do
        result = registry.deregister(:non_existent, callable_proc)

        expect(result).to be(registry)
      end
    end

    context "when deregistering the last callback of a type" do
      before do
        registry.register(:before_execution, callable_proc)
      end

      it "removes the type from the registry" do
        registry.deregister(:before_execution, callable_proc)

        expect(registry.registry).not_to have_key(:before_execution)
      end
    end

    context "when deregistering one of multiple callbacks" do
      before do
        registry.register(:before_execution, callable_proc)
        registry.register(:before_execution, callable_symbol)
      end

      it "removes only the specified callback" do
        registry.deregister(:before_execution, callable_proc)

        expect(registry.registry[:before_execution]).not_to include([[callable_proc], {}])
        expect(registry.registry[:before_execution]).to include([[callable_symbol], {}])
      end
    end
  end

  describe "#invoke" do
    context "when type is valid" do
      before do
        allow(CMDx::Utils::Condition).to receive(:evaluate).and_return(true)
      end

      context "with symbol callbacks" do
        before do
          registry.register(:before_execution, callable_symbol)
        end

        it "evaluates conditions for each callback entry" do
          allow(mock_task).to receive(:send).with(callable_symbol)
          expect(CMDx::Utils::Condition).to receive(:evaluate).with(mock_task, {})

          registry.invoke(:before_execution, mock_task)
        end

        it "invokes the symbol via task.send" do
          expect(mock_task).to receive(:send).with(callable_symbol)

          registry.invoke(:before_execution, mock_task)
        end
      end

      context "with proc callbacks" do
        before do
          registry.register(:before_execution, callable_proc)
        end

        it "invokes the proc via task.instance_exec" do
          expect(mock_task).to receive(:instance_exec) do |&block|
            expect(block).to eq(callable_proc)
          end

          registry.invoke(:before_execution, mock_task)
        end
      end

      context "with callable object callbacks" do
        before do
          registry.register(:before_execution, callable_object)
        end

        it "invokes the callable via .call" do
          expect(callable_object).to receive(:call).with(mock_task)

          registry.invoke(:before_execution, mock_task)
        end
      end

      context "when conditions are not met" do
        before do
          allow(CMDx::Utils::Condition).to receive(:evaluate).and_return(false)
          registry.register(:before_execution, callable_symbol)
        end

        it "does not invoke the callables" do
          expect(mock_task).not_to receive(:send)

          registry.invoke(:before_execution, mock_task)
        end
      end

      context "when multiple callback entries exist" do
        before do
          registry.register(:before_execution, callable_proc, if: :active?)
          registry.register(:before_execution, callable_symbol, unless: :disabled?)
          allow(mock_task).to receive(:send).with(callable_symbol)
          allow(mock_task).to receive(:instance_exec)
        end

        it "processes all entries" do
          expect(CMDx::Utils::Condition).to receive(:evaluate).twice

          registry.invoke(:before_execution, mock_task)
        end
      end
    end

    context "when type is invalid" do
      it "raises TypeError for unknown callback type" do
        expect { registry.invoke(:invalid_type, mock_task) }
          .to raise_error(TypeError, "unknown callback type :invalid_type")
      end
    end

    context "when no callbacks are registered for the type" do
      it "does not raise an error" do
        expect { registry.invoke(:before_execution, mock_task) }.not_to raise_error
      end

      it "does not attempt to invoke any callables" do
        expect(mock_task).not_to receive(:send)
        expect(mock_task).not_to receive(:instance_exec)

        registry.invoke(:before_execution, mock_task)
      end
    end

    context "when registry value is not a Set" do
      before do
        allow(CMDx::Utils::Condition).to receive(:evaluate).and_return(true)
        registry.registry[:before_execution] = [[callable_proc], {}]
      end

      it "handles Array conversion gracefully" do
        expect(mock_task).to receive(:instance_exec) do |&block|
          expect(block).to eq(callable_proc)
        end

        expect { registry.invoke(:before_execution, mock_task) }.not_to raise_error
      end
    end
  end
end
