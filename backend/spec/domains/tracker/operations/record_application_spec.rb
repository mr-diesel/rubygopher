require "rails_helper"

RSpec.describe Tracker::Operations::RecordApplication do
  let(:user) { create(:user) }
  let(:input) { { company_name: "Acme", vacancy_title: "Senior Ruby Developer", apply_url: "https://acme.io/jobs/1", comment: "via referral" } }

  subject(:result) { described_class.new.call(user, input) }

  it "creates the company, the vacancy, the application and its first event" do
    expect { result }.to change(Company, :count).by(1).and change(Vacancy, :count).by(1).and change(JobApplication, :count).by(1)

    application = result.value!
    expect(application).to have_attributes(status: "applied", apply_url: "https://acme.io/jobs/1")
    expect(application.company.name).to eq("Acme")
    expect(application.events.sole).to have_attributes(event_type: "status_changed", status: "applied", comment: "via referral")
    expect(application.last_activity_at).to eq(application.applied_at)
  end

  it "reuses an existing company and vacancy, matching names case-insensitively" do
    company = create(:company, name: "ACME")
    vacancy = create(:vacancy, company: company, title: "senior ruby developer")

    expect { result }.not_to change(Company, :count)
    expect(result.value!.vacancy).to eq(vacancy)
  end

  it "refuses a second application to the same vacancy" do
    first = described_class.new.call(user, input).value!

    expect(result).to be_failure
    expect(result.failure).to eq([ :duplicate, first ])
    expect(JobApplication.count).to eq(1)
  end

  it "lets another user track the same vacancy" do
    described_class.new.call(create(:user), input)

    expect(result).to be_success
  end

  context "with invalid input" do
    let(:input) { { company_name: "", vacancy_title: "Dev", apply_url: "not a url" } }

    it "fails with the validation errors and writes nothing" do
      expect { result }.not_to change(Company, :count)
      expect(result.failure.first).to eq(:invalid)
      expect(result.failure.last.keys).to contain_exactly(:company_name, :apply_url)
    end
  end

  it "stores the given dates and vacancy details" do
    input.merge!(applied_at: "2026-10-01T10:00:00Z", next_follow_up_at: "2026-10-08T10:00:00Z", language: "go", work_mode: "remote")

    application = result.value!
    expect(application.applied_at).to eq(Time.utc(2026, 10, 1, 10))
    expect(application.next_follow_up_at).to eq(Time.utc(2026, 10, 8, 10))
    expect(application.vacancy).to have_attributes(language: "go", work_mode: "remote")
  end
end
