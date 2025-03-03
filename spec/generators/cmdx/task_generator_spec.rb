# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cmdx::TaskGenerator, type: :generator do
  destination(File.expand_path("../../tmp", __FILE__))

  before do
    prepare_destination
    run_generator(%w[v1/notifications/send_email_task])
  end

  describe "#generator" do
    it "includes the proper markup" do
      sample_file  = File.read("spec/generators/tmp/app/cmds/v1/notifications/send_email_task.rb")
      text_snippet = "class V1::Notifications::SendEmailTask < ApplicationTask"

      expect(sample_file.include?(text_snippet)).to be(true)
    end
  end

end
