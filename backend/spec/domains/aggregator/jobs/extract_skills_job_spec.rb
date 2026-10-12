require "rails_helper"

RSpec.describe Aggregator::Jobs::ExtractSkillsJob do
  it "tags pending vacancies" do
    skill = create(:skill, name: "Redis", slug: "redis")
    vacancy = create(:vacancy, description: "Redis")

    described_class.perform_now

    expect(vacancy.reload.skills).to eq([ skill ])
  end
end
