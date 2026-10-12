require "rails_helper"

RSpec.describe Aggregator::Operations::ExtractSkills do
  let!(:ruby) { create(:skill, name: "Ruby", slug: "ruby") }
  let!(:kafka) { create(:skill, name: "Kafka", slug: "kafka", category: :tool) }
  let!(:postgres) { create(:skill, name: "PostgreSQL", slug: "postgresql", aliases: [ "Postgres" ], category: :database) }
  let(:vacancy) { create(:vacancy, title: "Backend developer", language: :ruby, description: "We run Kafka") }

  subject(:result) { described_class.new.call(vacancy) }

  it "links skills from the text, the boards' tags and the language, stamping the vacancy" do
    create(:vacancy_posting, vacancy: vacancy, tags: [ "Postgres" ])

    expect(result.value!).to contain_exactly(ruby, kafka, postgres)
    expect(vacancy.reload.skills).to contain_exactly(ruby, kafka, postgres)
    expect(vacancy.vacancy_skills.pluck(:source).uniq).to eq([ "dictionary" ])
    expect(vacancy.skills_extracted_at).to be_present
  end

  it "is idempotent and drops dictionary links that no longer match" do
    create(:vacancy_skill, vacancy: vacancy, skill: postgres, source: :dictionary)
    create(:vacancy_skill, vacancy: vacancy, skill: create(:skill, name: "Manual"), source: :manual)

    described_class.new.call(vacancy)

    expect { described_class.new.call(vacancy) }.not_to change(VacancySkill, :count)
    expect(vacancy.reload.skills.map(&:name)).to contain_exactly("Ruby", "Kafka", "Manual")
  end
end
