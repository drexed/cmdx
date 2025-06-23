# frozen_string_literal: true

RSpec.shared_context "parameter testing" do
  let(:default_context) do
    {
      title: "Mr.",
      first_name: "John",
      last_name: "Doe",
      address: {
        city: "Miami",
        "state" => "Fl"
      },
      company: instance_double("Company", name: "Ukea", position: "Cashier")
    }
  end

  let(:empty_context) { {} }
  let(:ctx) { default_context }
end

RSpec.shared_examples "parameter validation" do
  context "when parameters are valid" do
    it "processes successfully" do
      expect(result).to be_success
    end
  end

  context "when required parameters are missing" do
    let(:ctx) { empty_context }

    it "fails with validation error" do
      expect(result).to be_failed
      expect(result.state).to eq(CMDx::Result::INTERRUPTED)
      expect(result.status).to eq(CMDx::Result::FAILED)
    end
  end
end

RSpec.shared_examples "context parameter delegation" do
  it "successfully delegates to context attributes" do
    expect(result).to be_success
    expect(result.context).to have_attributes(expected_context_attributes)
  end
end

RSpec.shared_examples "source parameter delegation" do
  it "successfully delegates from specified source" do
    expect(result).to be_success
    expect(result.context).to have_attributes(expected_source_attributes)
  end
end
