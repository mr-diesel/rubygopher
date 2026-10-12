module Interview
  module API
    class Prompts < Grape::API
      helpers Identity::API::AuthHelpers

      before { authenticate! }

      desc "Prompt for a mock interview in any chat assistant: the vacancy, the candidate's résumé and skills, the gaps between them and the application's history. Without application_id it targets the stack of the user's active applications."
      params do
        optional :application_id, type: Integer, desc: "one of the user's applications"
      end
      get "interview/prompt" do
        application = params[:application_id] && current_user.job_applications.includes(:company, vacancy: :skills, via_posting: {}).find(params[:application_id])
        result = Queries::MockInterviewPrompt.new(current_user, application: application).call
        {
          title: result.title,
          prompt: result.prompt,
          application_id: application&.id,
          missing_skills: result.missing_skills.map(&:name)
        }
      end
    end
  end
end
