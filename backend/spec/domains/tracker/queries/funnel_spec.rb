require "rails_helper"

RSpec.describe Tracker::Queries::Funnel do
  let(:user) { create(:user) }

  def application(status_path, applied_at: 10.days.ago, reply_after: 2.days)
    app = create(:job_application, user: user, applied_at: applied_at, status: status_path.last)
    status_path.each_with_index do |status, i|
      create(:job_application_event, job_application: app, event_type: :status_changed, status: status,
                                     occurred_at: i.zero? ? applied_at : applied_at + reply_after + (i - 1).days)
    end
    app
  end

  it "counts every stage an application ever reached and the conversions between them" do
    application(%w[applied viewed screening tech_interview offer])
    application(%w[applied viewed screening rejected])
    application(%w[applied rejected], reply_after: 4.days)
    application(%w[applied])

    funnel = described_class.new(user).call[:applications]

    expect(funnel[:total]).to eq(4)
    expect(funnel[:stages].map { |s| [ s[:name], s[:count] ] }).to eq([ [ "applied", 4 ], [ "viewed", 2 ], [ "screening", 2 ], [ "tech_interview", 1 ], [ "offer", 1 ] ])
    expect(funnel[:stages][1]).to include(of_total: 50.0, of_previous: 50.0)
    expect(funnel[:stages][3]).to include(of_total: 25.0, of_previous: 50.0)
    expect(funnel[:rejected]).to eq(2)
    expect(funnel[:response_rate]).to eq(75.0)
    expect(funnel[:median_days_to_response]).to eq(2.0)
    expect(funnel[:by_status]).to eq("offer" => 1, "rejected" => 2, "applied" => 1)
  end

  it "limits to applications sent since a moment" do
    application(%w[applied viewed], applied_at: 60.days.ago)
    application(%w[applied], applied_at: 5.days.ago)

    funnel = described_class.new(user, since: 30.days.ago).call[:applications]

    expect(funnel[:total]).to eq(1)
    expect(funnel[:stages][1][:count]).to eq(0)
  end

  it "handles an empty tracker without dividing by zero" do
    funnel = described_class.new(user).call

    expect(funnel[:applications]).to include(total: 0, response_rate: nil, median_days_to_response: nil)
    expect(funnel[:applications][:stages].first).to include(count: 0, of_total: nil, of_previous: nil)
    expect(funnel[:outreach][:total]).to eq(0)
  end

  it "builds the outreach funnel from status events" do
    o1 = create(:company_outreach, user: user, status: :offer)
    %i[no_response talent_pool interview offer].each { |s| create(:company_outreach_event, company_outreach: o1, status: s) }
    o2 = create(:company_outreach, user: user, status: :rejected)
    %i[no_response rejected].each { |s| create(:company_outreach_event, company_outreach: o2, status: s) }
    create(:company_outreach, user: user)
    create(:company_outreach)

    funnel = described_class.new(user).call[:outreach]

    expect(funnel[:stages].map { |s| [ s[:name], s[:count] ] }).to eq([ [ "sent", 3 ], [ "responded", 2 ], [ "interview", 1 ], [ "offer", 1 ] ])
    expect(funnel[:rejected]).to eq(1)
  end
end
