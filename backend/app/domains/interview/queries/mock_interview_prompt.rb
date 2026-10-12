module Interview
  module Queries
    # Builds the prompt a chat assistant needs to run a mock interview: the vacancy,
    # the candidate (résumé + skills found in it), the gaps between the two and the
    # application's history. No LLM is called here; the user pastes the result into
    # any chat or the assistant fetches it through MCP.
    class MockInterviewPrompt
      Result = Data.define(:title, :prompt, :application, :missing_skills)

      DESCRIPTION_LIMIT = 4_000
      HISTORY_LIMIT = 8

      def initialize(user, application: nil, matcher: Aggregator::SkillMatcher.new)
        @user = user
        @application = application
        @matcher = matcher
      end

      def call
        resume_skills = @matcher.match(@user.resume)
        wanted = @application ? @application.vacancy.skills.to_a : stack_of_active_applications
        missing = wanted - resume_skills
        Result.new(title: title, prompt: render(resume_skills, wanted, missing), application: @application, missing_skills: missing)
      end

      private

      def title
        @application ? "Mock interview: #{@application.vacancy.title} at #{@application.company.name}" : "Mock interview: #{languages} backend"
      end

      def languages
        langs = @application ? [ @application.vacancy.language ] : @user.job_applications.active.joins(:vacancy).distinct.pluck("vacancies.language")
        langs.compact.map(&:capitalize).presence&.join("/") || "Ruby/Go"
      end

      def stack_of_active_applications
        Skill.joins(:vacancy_skills).where(vacancy_skills: { vacancy_id: @user.job_applications.active.select(:vacancy_id) })
             .group("skills.id").order(Arel.sql("COUNT(*) DESC"), :name).limit(12).to_a
      end

      def render(resume_skills, wanted, missing)
        [
          "# #{title}",
          "You are a senior #{languages} engineer interviewing a candidate. Run a realistic technical interview in this chat.",
          position_section(wanted),
          "## The candidate",
          resume_section(resume_skills),
          gaps_section(missing),
          history_section,
          "## How to run it",
          rules
        ].compact.join("\n\n") + "\n"
      end

      def rules
        <<~RULES.strip
          1. Introduce yourself in two sentences and start. Ask ONE question at a time and wait for the answer; never list several questions at once.
          2. Stages: a short warm-up about recent experience; 5–7 technical questions matching the stack above, from fundamentals to design, digging deeper whenever an answer is shallow; one small system-design task; then let the candidate ask questions.
          3. Do not reveal correct answers or grade answers during the interview. Keep notes silently.
          4. Stop when the candidate writes "stop" or after about 45 minutes of exchange. Then give a verdict: hire / no hire with a one-line reason, strengths, weak topics with what to read for each, and three questions to prepare for the real interview.
          5. Conduct the interview in the language the candidate answers in; the résumé and the vacancy show which one to open with.
          #{save_hint}
        RULES
      end

      def position_section(wanted)
        return general_position_section(wanted) unless @application

        vacancy = @application.vacancy
        lines = [ "## The position", "", "Company: #{@application.company.name}", "Title: #{vacancy.title}" ]
        lines << "Language: #{vacancy.language}" if vacancy.language.present?
        lines << "Work mode: #{[ vacancy.work_mode, vacancy.location ].compact.join(", ")}" if vacancy.work_mode || vacancy.location
        lines << "Vacancy link: #{@application.via_posting.url}" if @application.via_posting
        lines << "Skills mentioned: #{wanted.map(&:name).join(", ")}" if wanted.any?
        if vacancy.description.present?
          lines << "" << "Description:" << "" << vacancy.description.strip.truncate(DESCRIPTION_LIMIT, separator: " ")
        end
        lines.join("\n")
      end

      def general_position_section(wanted)
        lines = [ "## The position", "", "No specific vacancy: a #{languages} backend role matching the candidate's current applications." ]
        lines << "Stack seen across those vacancies: #{wanted.map(&:name).join(", ")}" if wanted.any?
        lines.join("\n")
      end

      def resume_section(resume_skills)
        if @user.resume.blank?
          return "No résumé on file. Open by asking the candidate for a three-sentence summary of their experience and stack."
        end

        lines = [ "Résumé:", "", @user.resume.strip ]
        lines << "" << "Skills found in the résumé: #{resume_skills.map(&:name).join(", ")}" if resume_skills.any?
        lines.join("\n")
      end

      def gaps_section(missing)
        return if missing.empty?

        "The position mentions skills the résumé does not: #{missing.map(&:name).join(", ")}. Probe these explicitly."
      end

      def history_section
        return unless @application

        events = @application.events.order(occurred_at: :desc, id: :desc).limit(HISTORY_LIMIT).reverse
        lines = [ "## Where this application stands", "", "Status: #{@application.status}; applied #{@application.applied_at.to_date}." ]
        events.each do |event|
          detail = [ event.status, event.comment.presence ].compact.join(": ")
          lines << "- #{event.occurred_at.to_date} #{event.event_type.humanize.downcase}#{" (#{detail})" if detail.present?}"
        end
        lines.join("\n")
      end

      def save_hint
        return unless @application

        "6. If you have the RubyGopher tools, offer to save the verdict as a note: add_application_event with application_id #{@application.id} and event_type note_added."
      end
    end
  end
end
