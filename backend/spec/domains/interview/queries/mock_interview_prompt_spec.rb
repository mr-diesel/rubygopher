require "rails_helper"

RSpec.describe Interview::Queries::MockInterviewPrompt do
  let!(:ruby) { create(:skill, name: "Ruby", slug: "ruby") }
  let!(:kafka) { create(:skill, name: "Kafka", slug: "kafka", category: :tool) }
  let!(:postgres) { create(:skill, name: "PostgreSQL", slug: "postgresql", category: :database) }
  let(:user) { create(:user, resume: "Senior Ruby developer, 5 years, PostgreSQL") }

  context "with an application" do
    let(:vacancy) { create(:vacancy, title: "Backend Ruby", description: "We run Kafka at scale", skills: [ ruby, kafka ]) }
    let(:application) { create(:job_application, user: user, vacancy: vacancy, company: vacancy.company, status: :tech_interview) }

    subject(:result) { described_class.new(user, application: application).call }

    before do
      create(:job_application_event, job_application: application, event_type: :status_changed, status: :screening, comment: "HR call went well", occurred_at: 2.days.ago)
    end

    it "describes the vacancy, the candidate and the application history" do
      expect(result.title).to eq("Mock interview: Backend Ruby at #{vacancy.company.name}")
      expect(result.prompt).to include("Company: #{vacancy.company.name}", "Skills mentioned: Ruby, Kafka", "We run Kafka at scale")
      expect(result.prompt).to include("Senior Ruby developer", "Skills found in the résumé: Ruby, PostgreSQL")
      expect(result.prompt).to include("Status: tech_interview", "status changed (screening: HR call went well)")
      expect(result.prompt).to include("add_application_event with application_id #{application.id}")
    end

    it "lists the skills the vacancy wants that the résumé lacks" do
      expect(result.missing_skills).to eq([ kafka ])
      expect(result.prompt).to include("skills the résumé does not: Kafka")
    end
  end

  context "without an application" do
    subject(:result) { described_class.new(user).call }

    it "targets the stack of the active applications" do
      create(:job_application, user: user, vacancy: create(:vacancy, language: :go, skills: [ kafka ]))
      create(:job_application, user: user, vacancy: create(:vacancy, language: :go, skills: [ kafka, postgres ]), archived_at: Time.current)

      expect(result.title).to eq("Mock interview: Go backend")
      expect(result.prompt).to include("Stack seen across those vacancies: Kafka")
      expect(result.prompt).not_to include("Where this application stands", "add_application_event")
    end

    it "asks for an introduction when there is no résumé" do
      user.update!(resume: nil)

      expect(result.prompt).to include("No résumé on file")
      expect(result.missing_skills).to be_empty
    end
  end
end
