require "rails_helper"

RSpec.describe Vacancy, type: :model do
  it { is_expected.to belong_to(:company) }
  it { is_expected.to have_many(:skills).through(:vacancy_skills) }
  it { is_expected.to validate_presence_of(:title) }

  describe ".skills_pending" do
    it "lists vacancies never scanned for skills" do
      pending = create(:vacancy)
      create(:vacancy, skills_extracted_at: Time.current)

      expect(described_class.skills_pending).to contain_exactly(pending)
    end
  end

  describe ".with_skill" do
    it "finds vacancies linked to the skill by slug" do
      tagged = create(:vacancy)
      create(:vacancy_skill, vacancy: tagged, skill: create(:skill, slug: "kafka"))
      create(:vacancy)

      expect(described_class.with_skill("kafka")).to contain_exactly(tagged)
    end
  end
end
