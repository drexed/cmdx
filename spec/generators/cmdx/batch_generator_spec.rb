# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cmdx::BatchGenerator, type: :generator do
  destination(File.expand_path("../../tmp", __FILE__))

  before do
    prepare_destination
    run_generator(%w[v1/users/batch_send_notifications])
  end

  describe "#generator" do
    it "includes the proper markup" do
      sample_file  = File.read("spec/generators/tmp/app/cmds/v1/users/batch_send_notifications.rb")
      text_snippet = "class V1::Users::BatchSendNotifications < ApplicationBatch"

      expect(sample_file.include?(text_snippet)).to be(true)
    end
  end

end
