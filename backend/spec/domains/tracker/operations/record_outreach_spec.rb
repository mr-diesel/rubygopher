require "rails_helper"

RSpec.describe Tracker::Operations::RecordOutreach do
  let(:user) { create(:user) }
  let(:input) { { company_name: "Acme", notes: "wrote to the CTO" } }

  subject(:result) { described_class.new.call(user, input) }

  it "creates the company, the outreach and its first event" do
    expect { result }.to change(Company, :count).by(1).and change(CompanyOutreach, :count).by(1)

    outreach = result.value!
    expect(outreach).to have_attributes(status: "no_response", notes: "wrote to the CTO")
    expect(outreach.events.sole).to have_attributes(status: "no_response", changed_at: outreach.sent_at)
  end

  it "reuses an existing company by name" do
    company = create(:company, name: "ACME")

    expect(result.value!.company).to eq(company)
  end

  it "refuses a second outreach to the same company" do
    first = described_class.new.call(user, input).value!

    expect(result.failure).to eq([ :duplicate, first ])
  end

  it "stores the given sent_at" do
    input[:sent_at] = "2026-09-30T08:00:00Z"

    expect(result.value!.sent_at).to eq(Time.utc(2026, 9, 30, 8))
  end

  it "fails on a blank company and writes nothing" do
    input[:company_name] = " "

    expect { result }.not_to change(Company, :count)
    expect(result.failure.first).to eq(:invalid)
  end
end
