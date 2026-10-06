require "rails_helper"

RSpec.describe Tracker::Queries::Digest do
  let(:user) { create(:user, created_at: 10.days.ago) }
  let(:now) { Time.current }

  subject(:digest) { described_class.new(user, now: now) }

  describe "follow-ups" do
    let!(:overdue) { create(:job_application, user: user, next_follow_up_at: 2.days.ago) }
    let!(:due_now) { create(:job_application, user: user, next_follow_up_at: 1.minute.ago) }
    let!(:soon) { create(:job_application, user: user, next_follow_up_at: 3.days.from_now) }

    before do
      create(:job_application, user: user, next_follow_up_at: 30.days.from_now)
      create(:job_application, user: user, next_follow_up_at: 1.day.ago, archived_at: now)
      create(:job_application, next_follow_up_at: 1.day.ago)
    end

    it "lists due follow-ups oldest first, skipping archived and other users'" do
      expect(digest.follow_ups_due).to eq([ overdue, due_now ])
    end

    it "lists follow-ups within the next week" do
      expect(digest.follow_ups_upcoming).to eq([ soon ])
    end
  end

  describe "new vacancies" do
    it "counts aggregated vacancies created since the user last looked, not manual ones" do
      user.update!(vacancies_seen_at: 1.day.ago)
      create(:vacancy_posting, source: :hh, vacancy: create(:vacancy, created_at: 1.hour.ago))
      create(:vacancy_posting, source: :getmatch, vacancy: create(:vacancy, created_at: 2.hours.ago))
      create(:vacancy_posting, source: :hh, vacancy: create(:vacancy, created_at: 3.days.ago))
      create(:vacancy_posting, source: :manual, vacancy: create(:vacancy, created_at: 1.hour.ago))
      create(:vacancy, created_at: 1.hour.ago)

      expect(digest.new_vacancies_count).to eq(2)
    end

    it "falls back to the sign-up date before the first visit" do
      expect(digest.new_vacancies_since).to eq(user.created_at)
    end
  end
end
