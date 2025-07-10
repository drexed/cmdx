# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ParameterRegistry do
  subject(:registry) { described_class.new }

  let(:valid_parameter) { mock_parameter(valid?: true, method_name: :param1, children: []) }
  let(:invalid_parameter) { mock_parameter(valid?: false, method_name: :param2, children: []) }
  let(:task) { mock_task }

  describe "#valid?" do
    context "when all parameters are valid" do
      before do
        registry.registry << valid_parameter
        registry.registry << mock_parameter(valid?: true)
      end

      it "returns true" do
        expect(registry.valid?).to be(true)
      end
    end

    context "when some parameters are invalid" do
      before do
        registry.registry << valid_parameter
        registry.registry << invalid_parameter
      end

      it "returns false" do
        expect(registry.valid?).to be(false)
      end
    end

    context "when all parameters are invalid" do
      before do
        registry.registry << invalid_parameter
        registry.registry << mock_parameter(valid?: false)
      end

      it "returns false" do
        expect(registry.valid?).to be(false)
      end
    end

    context "when registry is empty" do
      it "returns true" do
        expect(registry.valid?).to be(true)
      end
    end
  end

  describe "#invalid?" do
    context "when registry is valid" do
      before do
        registry.registry << valid_parameter
      end

      it "returns false" do
        expect(registry.invalid?).to be(false)
      end
    end

    context "when registry is invalid" do
      before do
        registry.registry << invalid_parameter
      end

      it "returns true" do
        expect(registry.invalid?).to be(true)
      end
    end

    context "when registry is empty" do
      it "returns false" do
        expect(registry.invalid?).to be(false)
      end
    end
  end

  describe "#validate!" do
    context "when validating simple parameters" do
      before do
        registry.registry << valid_parameter
        registry.registry << invalid_parameter
      end

      it "calls method for each parameter on task" do
        expect(task).to receive(:send).with(:param1)
        expect(task).to receive(:send).with(:param2)

        registry.validate!(task)
      end
    end

    context "when parameters have children" do
      let(:child_parameter) { mock_parameter(method_name: :child_param, children: []) }
      let(:parent_parameter) do
        mock_parameter(
          method_name: :parent_param,
          children: [child_parameter],
          valid?: true
        )
      end

      before do
        registry.registry << parent_parameter
      end

      it "validates parent and child parameters" do
        expect(task).to receive(:send).with(:parent_param)
        expect(task).to receive(:send).with(:child_param)

        registry.validate!(task)
      end
    end

    context "when parameters have nested children" do
      let(:grandchild_parameter) { mock_parameter(method_name: :grandchild_param, children: []) }
      let(:child_parameter) do
        mock_parameter(
          method_name: :child_param,
          children: [grandchild_parameter]
        )
      end
      let(:parent_parameter) do
        mock_parameter(
          method_name: :parent_param,
          children: [child_parameter],
          valid?: true
        )
      end

      before do
        registry.registry << parent_parameter
      end

      it "recursively validates all levels of nested parameters" do
        expect(task).to receive(:send).with(:parent_param)
        expect(task).to receive(:send).with(:child_param)
        expect(task).to receive(:send).with(:grandchild_param)

        registry.validate!(task)
      end

      it "validates nested parameters in depth-first order" do
        call_order = []
        allow(task).to receive(:send) { |method| call_order << method }

        registry.validate!(task)

        expect(call_order).to eq(%i[parent_param child_param grandchild_param])
      end
    end

    context "when multiple parameters have children" do
      let(:first_child_param) { mock_parameter(method_name: :child1, children: []) }
      let(:second_child_param) { mock_parameter(method_name: :child2, children: []) }
      let(:first_parent_param) do
        mock_parameter(
          method_name: :parent1,
          children: [first_child_param],
          valid?: true
        )
      end
      let(:second_parent_param) do
        mock_parameter(
          method_name: :parent2,
          children: [second_child_param],
          valid?: true
        )
      end

      before do
        registry.registry << first_parent_param
        registry.registry << second_parent_param
      end

      it "validates all parameters and their children" do
        expect(task).to receive(:send).with(:parent1)
        expect(task).to receive(:send).with(:child1)
        expect(task).to receive(:send).with(:parent2)
        expect(task).to receive(:send).with(:child2)

        registry.validate!(task)
      end
    end
  end

  describe "#to_h" do
    it "responds to to_h method" do
      expect(registry).to respond_to(:to_h)
    end
  end

  describe "#to_s" do
    it "responds to to_s method" do
      expect(registry).to respond_to(:to_s)
    end
  end

  describe "complex scenarios" do
    context "when registry has mixed parameter types with complex hierarchies" do
      let(:leaf_param) { mock_parameter(method_name: :leaf, children: [], valid?: true) }
      let(:branch_param) do
        mock_parameter(
          method_name: :branch,
          children: [leaf_param],
          valid?: false
        )
      end
      let(:root_param) do
        mock_parameter(
          method_name: :root,
          children: [branch_param],
          valid?: true
        )
      end

      before do
        registry.registry << root_param
        registry.registry << valid_parameter
      end

      it "correctly reports validity based on direct parameters only" do
        expect(registry.valid?).to be(true)
        expect(registry.invalid?).to be(false)
      end

      it "validates all parameters including nested ones" do
        expect(task).to receive(:send).with(:root)
        expect(task).to receive(:send).with(:branch)
        expect(task).to receive(:send).with(:leaf)
        expect(task).to receive(:send).with(:param1)

        registry.validate!(task)
      end
    end

    context "when working with large parameter collections" do
      before do
        10.times do |i|
          param = mock_parameter(method_name: :"param#{i}", children: [], valid?: true)
          registry.registry << param
        end
      end

      it "handles large collections efficiently" do
        expect(registry.registry.size).to eq(10)
        expect(registry.valid?).to be(true)
      end

      it "validates all parameters in large collections" do
        10.times { |i| expect(task).to receive(:send).with(:"param#{i}") }

        registry.validate!(task)
      end
    end

    context "when parameters raise exceptions during validation" do
      let(:failing_parameter) do
        mock_parameter(method_name: :failing_param, children: [], valid?: true)
      end

      before do
        registry.registry << failing_parameter
        allow(task).to receive(:send).with(:failing_param).and_raise(StandardError, "Validation failed")
      end

      it "allows exceptions to propagate" do
        expect { registry.validate!(task) }.to raise_error(StandardError, "Validation failed")
      end
    end
  end
end
