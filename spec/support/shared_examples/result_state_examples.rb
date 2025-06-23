# frozen_string_literal: true

RSpec.shared_examples "a successful result" do
  it "has successful result attributes" do
    expect(result).to be_success
    expect(result).to be_good
    expect(result).not_to be_bad
    expect(result).to have_attributes(
      state: CMDx::Result::COMPLETE,
      status: CMDx::Result::SUCCESS,
      metadata: {}
    )
  end
end

RSpec.shared_examples "a skipped result" do
  it "has skipped result attributes" do
    expect(result).to be_skipped
    expect(result).to be_good
    expect(result).to be_bad
    expect(result).to have_attributes(
      state: CMDx::Result::INTERRUPTED,
      status: CMDx::Result::SKIPPED,
      metadata: {}
    )
  end
end

RSpec.shared_examples "a failed result" do
  it "has failed result attributes" do
    expect(result).to be_failed
    expect(result).not_to be_good
    expect(result).to be_bad
    expect(result).to have_attributes(
      state: CMDx::Result::INTERRUPTED,
      status: CMDx::Result::FAILED,
      metadata: {}
    )
  end
end

RSpec.shared_examples "result state predicates" do |expected_state|
  let(:state_methods) do
    {
      CMDx::Result::INITIALIZED => :initialized?,
      CMDx::Result::EXECUTING => :executing?,
      CMDx::Result::COMPLETE => :complete?,
      CMDx::Result::INTERRUPTED => :interrupted?
    }
  end

  it "returns correct state predicate values" do
    state_methods.each do |state, method|
      expected_value = state == expected_state
      expect(result.public_send(method)).to eq(expected_value)
    end
  end
end

RSpec.shared_examples "result status predicates" do |expected_status|
  let(:status_methods) do
    {
      CMDx::Result::SUCCESS => :success?,
      CMDx::Result::SKIPPED => :skipped?,
      CMDx::Result::FAILED => :failed?
    }
  end

  it "returns correct status predicate values" do
    status_methods.each do |status, method|
      expected_value = status == expected_status
      expect(result.public_send(method)).to eq(expected_value)
    end
  end
end
