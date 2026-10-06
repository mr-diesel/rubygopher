module Agent
  module Mcp
    module Tools
      STATUS = { type: "string", enum: JobApplication.statuses.keys }.freeze
      DATE = { type: "string", description: "ISO 8601 date-time" }.freeze

      class RecordApplication < BaseTool
        tool_name "record_application"
        description "Record that the user applied to a vacancy. Give the vacancy url (hh.ru, career.habr.com, getmatch.ru and hirify.me links resolve the company and title by themselves) or company_name + vacancy_title. 'already tracked' means it exists; use that id."
        input_schema(
          properties: {
            url: { type: "string", description: "vacancy link" },
            company_name: { type: "string" },
            vacancy_title: { type: "string" },
            applied_at: DATE,
            comment: { type: "string", description: "how they applied, who referred, anything worth remembering" },
            next_follow_up_at: DATE
          }
        )

        def self.call(server_context:, **args)
          present(Tracker::Operations::RecordApplication.new.call(user(server_context), args), Tracker::API::Entities::Application, full: true)
        end
      end

      class AddApplicationEvent < BaseTool
        tool_name "add_application_event"
        description "Append to an application's history: a status change (HR called, interview, offer, rejection), a note, a scheduled interview, or a sent follow-up with the next reminder date."
        input_schema(
          properties: {
            application_id: { type: "integer" },
            event_type: { type: "string", enum: JobApplicationEvent.event_types.keys },
            status: STATUS.merge(description: "required for status_changed"),
            comment: { type: "string" },
            occurred_at: DATE,
            next_follow_up_at: DATE.merge(description: "when to remind about this application again; null clears the reminder")
          },
          required: %w[application_id event_type]
        )

        def self.call(application_id:, server_context:, **args)
          present(Tracker::Operations::AddEvent.new.call(user(server_context), application_id, args), Tracker::API::Entities::Event)
        end
      end

      class ListApplications < BaseTool
        tool_name "list_applications"
        description "List the user's applications, newest activity first, optionally filtered by status. Use it to find an application_id."
        input_schema(properties: { status: STATUS, archived: { type: "boolean" } })

        def self.call(server_context:, status: nil, archived: false)
          scope = user(server_context).job_applications.includes(:company, :vacancy, :via_posting).order(last_activity_at: :desc, id: :desc)
          scope = archived ? scope.archived : scope.active
          scope = scope.where(status: status) if status
          ok(Tracker::API::Entities::Application.represent(scope.to_a))
        end
      end

      class GetApplication < BaseTool
        tool_name "get_application"
        description "One application with its full history."
        input_schema(properties: { application_id: { type: "integer" } }, required: %w[application_id])

        def self.call(application_id:, server_context:)
          application = user(server_context).job_applications.includes(:company, :vacancy, :via_posting, :events).find_by(id: application_id)
          application ? ok(Tracker::API::Entities::Application.represent(application, full: true)) : failed([ :not_found ])
        end
      end

      class RecordOutreach < BaseTool
        tool_name "record_outreach"
        description "Record a cold email or message the user sent to a company (not an application to a specific vacancy)."
        input_schema(properties: { company_name: { type: "string" }, sent_at: DATE, notes: { type: "string" } }, required: %w[company_name])

        def self.call(server_context:, **args)
          present(Tracker::Operations::RecordOutreach.new.call(user(server_context), args), Tracker::API::Entities::Outreach, full: true)
        end
      end

      class ChangeOutreachStatus < BaseTool
        tool_name "change_outreach_status"
        description "Record what happened to a cold outreach: no_response, talent_pool, interview, offer or rejected."
        input_schema(
          properties: { outreach_id: { type: "integer" }, status: { type: "string", enum: CompanyOutreach.statuses.keys }, comment: { type: "string" }, changed_at: DATE },
          required: %w[outreach_id status]
        )

        def self.call(outreach_id:, server_context:, **args)
          present(Tracker::Operations::ChangeOutreachStatus.new.call(user(server_context), outreach_id, args), Tracker::API::Entities::OutreachEvent)
        end
      end

      class ListOutreaches < BaseTool
        tool_name "list_outreaches"
        description "List cold outreach, newest first, optionally filtered by status."
        input_schema(properties: { status: { type: "string", enum: CompanyOutreach.statuses.keys } })

        def self.call(server_context:, status: nil)
          scope = user(server_context).company_outreaches.includes(:company).order(sent_at: :desc, id: :desc)
          scope = scope.where(status: status) if status
          ok(Tracker::API::Entities::Outreach.represent(scope.to_a))
        end
      end

      class Digest < BaseTool
        tool_name "digest"
        description "What needs attention now: follow-ups that are due, follow-ups coming up this week, and how many new vacancies appeared in the feed."
        input_schema(properties: {})

        def self.call(server_context:)
          digest = Tracker::Queries::Digest.new(user(server_context))
          ok(
            follow_ups: {
              due: Tracker::API::Entities::Application.represent(digest.follow_ups_due.to_a),
              upcoming: Tracker::API::Entities::Application.represent(digest.follow_ups_upcoming.to_a)
            },
            new_vacancies: { count: digest.new_vacancies_count, since: digest.new_vacancies_since }
          )
        end
      end

      class Funnel < BaseTool
        tool_name "funnel"
        description "Pipeline analytics: how many applications reached each stage, conversions, reply rate, median days to the first reply."
        input_schema(properties: { since: DATE.merge(description: "only applications sent after this moment") })

        def self.call(server_context:, since: nil)
          ok(Tracker::Queries::Funnel.new(user(server_context), since: since && Time.zone.parse(since)).call)
        end
      end

      ALL = [ RecordApplication, AddApplicationEvent, ListApplications, GetApplication, RecordOutreach, ChangeOutreachStatus, ListOutreaches, Digest, Funnel ].freeze
    end
  end
end
