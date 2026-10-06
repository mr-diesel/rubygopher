require "rails_helper"

RSpec.describe Tracker::Events do
  let(:user) { create(:user) }

  it "records an outbox event when an application is recorded" do
    result = Tracker::Operations::RecordApplication.new.call(user, company_name: "Acme", vacancy_title: "Dev")

    event = Outbox::Event.sole
    expect(event).to have_attributes(topic: "tracker.events", key: "user:#{user.id}", event_type: "application.recorded")
    expect(event.payload).to include("application_id" => result.value!.id, "company" => "Acme", "status" => "applied", "user_id" => user.id)
  end

  it "carries the user's telegram chat so the notifier needs no lookup" do
    user.update!(telegram_chat_id: 99)

    Tracker::Operations::RecordApplication.new.call(user, company_name: "Acme", vacancy_title: "Dev")

    expect(Outbox::Event.sole.payload).to include("telegram_chat_id" => 99)
  end

  it "records nothing when the operation fails" do
    Tracker::Operations::RecordApplication.new.call(user, company_name: "", vacancy_title: "Dev")

    expect(Outbox::Event.count).to eq(0)
  end

  it "records status changes on applications and outreach" do
    application = create(:job_application, user: user)
    outreach = create(:company_outreach, user: user)

    Tracker::Operations::AddEvent.new.call(user, application.id, event_type: "status_changed", status: "offer")
    Tracker::Operations::ChangeOutreachStatus.new.call(user, outreach.id, status: "interview")

    expect(Outbox::Event.pluck(:event_type)).to contain_exactly("application.event_added", "outreach.status_changed")
    expect(Outbox::Event.find_by(event_type: "application.event_added").payload.dig("event", "status")).to eq("offer")
  end
end
