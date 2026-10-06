require "rails_helper"

RSpec.describe Aggregator::Operations::IngestPosting do
  let(:input) do
    {
      source: "hh", external_id: "hh-1", url: "https://hh.ru/vacancy/1", title: "Senior Ruby Developer",
      company: { name: "Acme", external_id: "hh-c-9" }, language: "ruby", work_mode: "remote",
      salary_min: 300_000, currency: "RUB", published_at: "2026-10-01T10:00:00Z", raw: { "id" => 1 }
    }
  end

  subject(:result) { described_class.new.call(input) }

  it "creates the company, the vacancy and the posting" do
    expect { result }.to change(Company, :count).by(1).and change(Vacancy, :count).by(1).and change(VacancyPosting, :count).by(1)

    posting = result.value!
    expect(posting).to have_attributes(source: "hh", external_id: "hh-1", active: true, raw: { "id" => 1 })
    expect(posting.vacancy).to have_attributes(title: "Senior Ruby Developer", language: "ruby", work_mode: "remote", salary_min: 300_000)
    expect(posting.vacancy.company).to have_attributes(name: "Acme", source: "hh", external_id: "hh-c-9")
  end

  it "is idempotent: a replayed posting only refreshes last_seen_at" do
    posting = described_class.new.call(input).value!
    posting.update!(last_seen_at: 2.days.ago, active: false)

    expect { result }.not_to change(VacancyPosting, :count)
    expect(posting.reload).to have_attributes(active: true)
    expect(posting.last_seen_at).to be_within(2.seconds).of(Time.current)
  end

  it "attaches a second board's posting to the same vacancy by company and title" do
    described_class.new.call(input).value!

    other = described_class.new.call(input.merge(source: "getmatch", external_id: "gm-5", company: { name: "ACME" })).value!

    expect(Vacancy.count).to eq(1)
    expect(other.vacancy.postings.count).to eq(2)
  end

  it "finds the company by the board's id even if it was renamed" do
    company = create(:company, name: "Acme Corp", source: :hh, external_id: "hh-c-9")

    expect(result.value!.vacancy.company).to eq(company)
  end

  it "rejects manual as a source and bad payloads without writing" do
    expect { described_class.new.call(input.merge(source: "manual")) }.not_to change(Company, :count)
    expect(described_class.new.call({}).failure.first).to eq(:invalid)
  end
end
