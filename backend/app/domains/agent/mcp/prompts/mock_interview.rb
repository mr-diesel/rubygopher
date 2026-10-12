module Agent
  module Mcp
    module Prompts
      class MockInterview < MCP::Prompt
        prompt_name "mock_interview"
        title "Mock interview"
        description "Run a technical mock interview for one of the user's applications (or for their general stack) based on the vacancy, their résumé and the application history."
        arguments [ MCP::Prompt::Argument.new(name: "application_id", description: "id from list_applications; omit for a general interview", required: false) ]

        def self.template(args, server_context:)
          user = server_context.fetch(:user)
          application = args[:application_id].present? && user.job_applications.find_by(id: args[:application_id])
          raise MCP::Server::RequestHandlerError.new("application not found", nil, error_type: :invalid_params, error_code: JsonRpcHandler::ErrorCode::INVALID_PARAMS) if application.nil? && args[:application_id].present?

          result = Interview::Queries::MockInterviewPrompt.new(user, application: application || nil).call
          MCP::Prompt::Result.new(
            description: result.title,
            messages: [ MCP::Prompt::Message.new(role: "user", content: MCP::Content::Text.new(result.prompt)) ]
          )
        end
      end
    end
  end
end
