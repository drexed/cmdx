# frozen_string_literal: true

RSpec.describe CMDx::Retriers::Fibonacci do
  describe ".call" do
    it "scales by the Fibonacci sequence" do
      expect((0..5).map { |attempt| described_class.call(attempt, 1.0) })
        .to eq([1.0, 1.0, 2.0, 3.0, 5.0, 8.0])
    end
  end
end
