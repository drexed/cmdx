# frozen_string_literal: true

RSpec.describe CMDx do

  around do |ex|
    old_config = described_class.configuration.to_h
    ex.run
    described_class.configuration.merge!(old_config)
    I18n.locale = :en
  end

  describe "#configuration" do
    it "sets value to :foo" do
      described_class.configuration.task_timeout = :foo

      expect(described_class.configuration.task_timeout).to eq(:foo)
    end
  end

  describe "#configure" do
    it "sets value to :bar" do
      described_class.configure { |config| config.task_timeout = :bar }

      expect(described_class.configuration.task_timeout).to eq(:bar)
    end
  end

  describe "#reset_configuration!" do
    it "resets value to default" do
      described_class.configuration.task_timeout = :buzz
      described_class.reset_configuration!

      expect(described_class.configuration.task_timeout).to be_nil
    end
  end

end
