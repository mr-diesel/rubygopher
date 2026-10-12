require "rails_helper"

RSpec.describe Aggregator::Operations::ExtractPendingSkills do
  let!(:kafka) { create(:skill, name: "Kafka", slug: "kafka", category: :tool) }
  let!(:pending) { create(:vacancy, description: "Kafka", language: :go) }
  let!(:done) { create(:vacancy, description: "Kafka", skills_extracted_at: 1.day.ago) }

  it "tags only vacancies never scanned and reports the count" do
    expect(described_class.new.call.value!).to eq(1)
    expect(pending.reload.skills).to eq([ kafka ])
    expect(done.reload.skills).to be_empty
  end

  it "does nothing on a second run" do
    described_class.new.call

    expect { described_class.new.call }.not_to change(VacancySkill, :count)
  end
end
