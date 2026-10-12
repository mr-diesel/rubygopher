require "rails_helper"

RSpec.describe Agent::Mcp::Tools do
  let(:user) { create(:user) }
  let(:context) { { user: user } }

  def text(response)
    JSON.parse(response.content.first[:text])
  end

  it "adds an event with a follow-up and shows it in the digest" do
    application = create(:job_application, user: user)

    response = described_class::AddApplicationEvent.call(
      application_id: application.id, event_type: "follow_up_sent", next_follow_up_at: 1.hour.ago.iso8601, server_context: context
    )
    expect(response.error?).to be(false)
    expect(text(response)).to include("event_type" => "follow_up_sent")

    digest = text(described_class::Digest.call(server_context: context))
    expect(digest.dig("follow_ups", "due").map { |a| a["id"] }).to eq([ application.id ])
  end

  it "runs the outreach tools end to end" do
    created = text(described_class::RecordOutreach.call(company_name: "Globex", notes: "cold email", server_context: context))

    changed = described_class::ChangeOutreachStatus.call(outreach_id: created["id"], status: "interview", server_context: context)
    expect(text(changed)).to include("status" => "interview")

    listed = text(described_class::ListOutreaches.call(status: "interview", server_context: context))
    expect(listed.map { |o| o["id"] }).to eq([ created["id"] ])
  end

  it "answers the funnel with a since filter" do
    create(:job_application, user: user, applied_at: 2.days.ago)
    create(:job_application, user: user, applied_at: 40.days.ago)

    funnel = text(described_class::Funnel.call(since: 7.days.ago.iso8601, server_context: context))
    expect(funnel.dig("applications", "total")).to eq(1)
  end

  it "returns the interview prompt as plain text and not_found for a foreign application" do
    application = create(:job_application, user: user)

    response = described_class::InterviewPrompt.call(application_id: application.id, server_context: context)
    expect(response.error?).to be(false)
    expect(response.content.first[:text]).to start_with("# Mock interview: #{application.vacancy.title}")

    foreign = described_class::InterviewPrompt.call(application_id: create(:job_application).id, server_context: context)
    expect(foreign.error?).to be(true)
  end

  it "lists the vacancy feed with the skill filter, the dictionary, and marks the feed seen" do
    user.update!(vacancies_seen_at: 1.day.ago)
    kafka = create(:skill, name: "Kafka", slug: "kafka", category: :tool)
    tagged = create(:vacancy, title: "Go with Kafka", language: :go)
    create(:vacancy_posting, vacancy: tagged, source: :getmatch, url: "https://getmatch.ru/vacancies/1")
    create(:vacancy_skill, vacancy: tagged, skill: kafka)
    create(:vacancy_posting, vacancy: create(:vacancy, title: "Plain Ruby"))

    feed = text(described_class::ListVacancies.call(language: "go", skill: "kafka", server_context: context))
    expect(feed["total"]).to eq(1)
    expect(feed["vacancies"].first).to include("title" => "Go with Kafka", "new" => true)
    expect(feed["vacancies"].first["postings"].first["url"]).to eq("https://getmatch.ru/vacancies/1")

    expect(text(described_class::ListSkills.call(server_context: context))).to eq([ { "slug" => "kafka", "name" => "Kafka", "category" => "tool", "vacancies_count" => 1 } ])

    described_class::MarkVacanciesSeen.call(server_context: context)
    expect(text(described_class::ListVacancies.call(only_new: true, server_context: context))["total"]).to eq(0)
  end
end
