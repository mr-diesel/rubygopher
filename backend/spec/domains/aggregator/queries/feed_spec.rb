require "rails_helper"

RSpec.describe Aggregator::Queries::Feed do
  let(:user) { create(:user, created_at: 10.days.ago, vacancies_seen_at: 2.days.ago) }

  def aggregated(title, source: :hh, created_at: 1.day.ago, **attrs)
    vacancy = create(:vacancy, title: title, created_at: created_at, **attrs)
    create(:vacancy_posting, vacancy: vacancy, source: source)
    vacancy
  end

  it "lists aggregated vacancies newest first and skips manual ones" do
    old = aggregated("Old Ruby", created_at: 5.days.ago)
    fresh = aggregated("Fresh Go", language: :go)
    manual = create(:vacancy, title: "Manual")
    create(:vacancy_posting, vacancy: manual, source: :manual)

    page = described_class.new(user).call

    expect(page.vacancies).to eq([ fresh, old ])
    expect(page.total).to eq(2)
  end

  it "hides vacancies whose postings were all closed" do
    gone = aggregated("Gone")
    gone.postings.update_all(active: false)
    aggregated("Still here")

    expect(described_class.new(user).call.vacancies.map(&:title)).to eq([ "Still here" ])
  end

  it "marks what is new and what the user already applied to" do
    fresh = aggregated("Fresh")
    old = aggregated("Old", created_at: 5.days.ago)
    application = create(:job_application, user: user, vacancy: old)

    vacancies = described_class.new(user).call.vacancies.index_by(&:id)

    expect(vacancies[fresh.id]).to have_attributes(new_for_user: true, application_id: nil)
    expect(vacancies[old.id]).to have_attributes(new_for_user: false, application_id: application.id)
  end

  it "filters by language, work mode, source, novelty and text" do
    aggregated("Ruby remote hh", language: :ruby, work_mode: :remote)
    aggregated("Go onsite habr", language: :go, work_mode: :onsite, source: :habr_career, created_at: 5.days.ago)

    expect(described_class.new(user, language: "go").call.total).to eq(1)
    expect(described_class.new(user, work_mode: "remote").call.total).to eq(1)
    expect(described_class.new(user, source: "habr_career").call.vacancies.map(&:title)).to eq([ "Go onsite habr" ])
    expect(described_class.new(user, only_new: true).call.vacancies.map(&:title)).to eq([ "Ruby remote hh" ])
    expect(described_class.new(user, q: "onsite").call.vacancies.map(&:title)).to eq([ "Go onsite habr" ])
  end

  it "paginates" do
    stub_const("Aggregator::Queries::Feed::PER_PAGE", 2)
    3.times { |i| aggregated("V#{i}", created_at: i.hours.ago) }

    first = described_class.new(user, page: 1).call
    second = described_class.new(user, page: 2).call

    expect(first.vacancies.size).to eq(2)
    expect(second.vacancies.map(&:title)).to eq([ "V2" ])
    expect(second.total).to eq(3)
  end
end
