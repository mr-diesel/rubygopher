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
end
