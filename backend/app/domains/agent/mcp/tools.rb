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

      class InterviewPrompt < BaseTool
        tool_name "interview_prompt"
        description "Prompt for running a mock interview right here in the chat: the vacancy, the user's résumé and skills, the gaps and the application history, plus the rules of the interview. Fetch it, then follow it. Omit application_id for a general interview on the user's stack."
        input_schema(properties: { application_id: { type: "integer" } })

        def self.call(server_context:, application_id: nil)
          application = application_id && user(server_context).job_applications.find_by(id: application_id)
          return failed([ :not_found ]) if application_id && application.nil?

          result = Interview::Queries::MockInterviewPrompt.new(user(server_context), application: application || nil).call
          MCP::Tool::Response.new([ { type: "text", text: result.prompt } ])
        end
      end

      class ListVacancies < BaseTool
        tool_name "list_vacancies"
        description "The aggregated Ruby/Go vacancy feed (hh.ru, Habr Career, getmatch, hirify), newest first, 30 per page. Filters combine with AND; `skill` is a slug from list_skills. Each vacancy carries `new` (appeared since the user last looked) and `application_id` (already applied). Use the first posting's url with record_application."
        input_schema(
          properties: {
            language: { type: "string", enum: ::Vacancy.languages.keys },
            work_mode: { type: "string", enum: ::Vacancy.work_modes.keys },
            source: { type: "string", enum: VacancyPosting.sources.keys - [ "manual" ] },
            skill: { type: "string", description: "skill slug, e.g. kafka" },
            only_new: { type: "boolean" },
            q: { type: "string", description: "substring of the title or description" },
            page: { type: "integer" }
          }
        )

        def self.call(server_context:, page: 1, **filters)
          feed = Aggregator::Queries::Feed.new(user(server_context), page: page, **filters).call
          ok(vacancies: Aggregator::API::Entities::Vacancy.represent(feed.vacancies), total: feed.total, page: feed.page, per_page: feed.per_page)
        end
      end

      class ListSkills < BaseTool
        tool_name "list_skills"
        description "Skills dictionary with the number of open vacancies mentioning each; gives the slugs for list_vacancies' skill filter."
        input_schema(properties: {})

        def self.call(server_context:)
          counts = VacancySkill.where(vacancy_id: VacancyPosting.active.where.not(source: :manual).select(:vacancy_id)).group(:skill_id).count
          ok(::Skill.order(:category, :name).map { |skill| Aggregator::API::Entities::Skill.represent(skill, vacancies_count: counts.fetch(skill.id, 0)) })
        end
      end

      class MarkVacanciesSeen < BaseTool
        tool_name "mark_vacancies_seen"
        description "Stop counting the current feed as new (after the user has looked through it)."
        input_schema(properties: {})

        def self.call(server_context:)
          user(server_context).update!(vacancies_seen_at: Time.current)
          ok(seen_at: user(server_context).vacancies_seen_at)
        end
      end

      ALL = [ RecordApplication, AddApplicationEvent, ListApplications, GetApplication, RecordOutreach, ChangeOutreachStatus, ListOutreaches,
              Digest, Funnel, InterviewPrompt, ListVacancies, ListSkills, MarkVacanciesSeen ].freeze
    end
  end
end
