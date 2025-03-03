# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::InstallGenerator, type: :generator do
  destination(File.expand_path("../../tmp", __FILE__))

  let(:sample_path) { "spec/generators/tmp/config/initializers/cmdx.rb" }

  before do
    prepare_destination
    run_generator
  end

  describe "#generator" do
    it "creates a matching file" do
      sample_file = File.read(sample_path)
      expect_file = File.read("lib/generators/cmdx/templates/install.rb")

      expect(sample_file).to eq(expect_file)
    end
  end

end
