require "rails_helper"

RSpec.describe JobApplication do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:vacancy) }
  it { is_expected.to have_many(:events).dependent(:delete_all) }

  describe "scopes" do
    let!(:active) { create(:job_application, next_follow_up_at: 1.hour.ago) }
    let!(:later) { create(:job_application, next_follow_up_at: 1.day.from_now) }
    let!(:archived) { create(:job_application, archived_at: Time.current, next_follow_up_at: 1.hour.ago) }

    it "separates active and archived applications" do
      expect(described_class.active).to contain_exactly(active, later)
      expect(described_class.archived).to contain_exactly(archived)
    end

    it "finds active applications whose follow-up is due" do
      expect(described_class.follow_up_due).to contain_exactly(active)
    end
  end
end
