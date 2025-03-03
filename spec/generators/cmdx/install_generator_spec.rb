# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cmdx::InstallGenerator, type: :generator do
  destination(File.expand_path("../../tmp", __FILE__))

  before do
    prepare_destination
    run_generator
  end

  describe "#generator" do
    it "creates a matching file" do
      sample_file = File.read("spec/generators/tmp/config/initializers/cmdx.rb")
      expect_file = File.read("lib/generators/cmdx/templates/install.rb")

      expect(sample_file).to eq(expect_file)
    end
  end

end
