require "rails_helper"

RSpec.describe Tracker::Operations::RecordApplication do
  let(:user) { create(:user) }
  let(:input) { { company_name: "Acme", vacancy_title: "Senior Ruby Developer", url: "https://acme.io/jobs/1", comment: "via referral" } }

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
    let(:input) { { company_name: "", vacancy_title: "Dev", url: "not a url" } }

    it "fails with the validation errors and writes nothing" do
      expect { result }.not_to change(Company, :count)
      expect(result.failure.first).to eq(:invalid)
      expect(result.failure.last.keys).to contain_exactly(:url)
    end
  end

  it "requires either a url or company and title" do
    result = described_class.new.call(user, company_name: "Acme")

    expect(result.failure).to eq([ :invalid, { nil => [ "give the vacancy url, or company_name and vacancy_title" ] } ])
  end

  describe "by job-board link" do
    let(:hh) { instance_double(Aggregator::Clients::Hh) }

    subject(:result) { described_class.new(hh: hh).call(user, input) }

    context "when the posting is already collected" do
      let(:posting) { create(:vacancy_posting, source: :hh, external_id: "42", url: "https://hh.ru/vacancy/42") }
      let(:input) { { url: "https://hh.ru/vacancy/42?from=search" } }

      it "attaches the application to that vacancy without calling hh.ru" do
        posting

        application = result.value!
        expect(application.vacancy).to eq(posting.vacancy)
        expect(application.via_posting).to eq(posting)
        expect(application.apply_url).to eq("https://hh.ru/vacancy/42?from=search")
      end
    end

    context "when an hh.ru vacancy is not collected yet" do
      let(:input) { { url: "https://hh.ru/vacancy/777" } }
      let(:fetched) do
        { source: "hh", external_id: "777", url: "https://hh.ru/vacancy/777", title: "Go Engineer", company: { name: "Globex", external_id: "5" } }
      end

      it "fetches it, ingests it and tracks the application" do
        allow(hh).to receive(:fetch_vacancy).with("777").and_return(fetched)

        application = result.value!
        expect(application.vacancy.title).to eq("Go Engineer")
        expect(application.company.name).to eq("Globex")
        expect(application.via_posting).to have_attributes(source: "hh", external_id: "777")
      end

      it "reports an unknown vacancy" do
        allow(hh).to receive(:fetch_vacancy).and_raise(Aggregator::Clients::Hh::NotFound)

        expect(result.failure).to eq([ :invalid, { url: [ "hh.ru does not know this vacancy" ] } ])
      end

      it "reports hh.ru being down without writing anything" do
        allow(hh).to receive(:fetch_vacancy).and_raise(Aggregator::Clients::Hh::Error, "hh.ru unavailable: timeout")

        expect { result }.not_to change(JobApplication, :count)
        expect(result.failure).to eq([ :unavailable, "hh.ru unavailable: timeout" ])
      end
    end

    context "when a habr link is not collected yet" do
      let(:input) { { url: "https://career.habr.com/vacancies/1000" } }

      it "asks for company and title" do
        expect(result.failure.last[:url].sole).to include("not collected yet")
      end

      it "uses company and title when they are given" do
        input.merge!(company_name: "Habr Co", vacancy_title: "Ruby dev")

        expect(result.value!.company.name).to eq("Habr Co")
      end
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
