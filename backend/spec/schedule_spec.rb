require "rails_helper"

RSpec.describe "config/schedule.yml" do
  let(:schedule) { YAML.load_file(Rails.root.join("config/schedule.yml")) }

  it "names existing jobs with valid cron lines and known queues" do
    expect(schedule.keys).to contain_exactly("follow_up_reminders", "outbox_sweep", "close_stale_postings", "purge_console_sessions")
    schedule.each_value do |job|
      expect(job["class"].constantize).to be < ApplicationJob
      expect(Fugit.parse_cron(job["cron"])).not_to be_nil
      expect(%w[critical default low]).to include(job["queue"])
    end
  end
end
