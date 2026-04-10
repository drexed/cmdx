# frozen_string_literal: true

RSpec.describe CMDx::Definition do
  let(:parent_task) do
    Class.new(CMDx::Task) do
      required :name, :string
      on_success :log_it

      private

      def log_it; end
    end
  end

  let(:child_task) do
    Class.new(parent_task) do
      required :email, :string
      on_failed :handle_fail

      private

      def handle_fail; end
    end
  end

  describe ".fetch" do
    it "returns a frozen Definition" do
      defn = described_class.fetch(parent_task)
      expect(defn).to be_frozen
      expect(defn.attributes.size).to eq(1)
    end

    it "caches the definition" do
      d1 = described_class.fetch(parent_task)
      d2 = described_class.fetch(parent_task)
      expect(d1).to be(d2)
    end
  end

  describe ".compile with inheritance" do
    it "merges parent attributes" do
      defn = described_class.fetch(child_task)
      names = defn.attributes.map(&:name)
      expect(names).to contain_exactly(:name, :email)
    end

    it "merges parent callbacks" do
      defn = described_class.fetch(child_task)
      expect(defn.callbacks[:on_success]).not_to be_empty
      expect(defn.callbacks[:on_failed]).not_to be_empty
    end
  end

  describe ".root" do
    it "returns a definition from global configuration" do
      root = described_class.root
      expect(root.coercions).to include(:string, :integer, :boolean)
      expect(root.validators).to include(:presence, :format)
    end
  end
end
