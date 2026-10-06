module Tracker
  module Queries
    # How applications move through the pipeline. "Reached" counts come from the
    # event history, so an application that went screening → rejected still counts
    # for screening; the current status alone would hide that.
    class Funnel
      STAGES = %w[applied viewed screening tech_interview offer].freeze
      OUTREACH_STAGES = %w[sent responded interview offer].freeze

      def initialize(user, since: nil)
        @user = user
        @since = since
      end

      def call
        { since: @since, applications: applications, outreach: outreach }
      end

      private

      def applications
        scope = @user.job_applications
        scope = scope.where(applied_at: @since..) if @since
        total = scope.count
        reached = reached_by_status(scope)
        reached["applied"] = total
        responded = responded_count(scope)

        {
          total: total,
          stages: stages(STAGES, reached),
          rejected: reached["rejected"] || 0,
          response_rate: rate(responded, total),
          median_days_to_response: median_days(scope),
          by_status: scope.group(:status).count
        }
      end

      def outreach
        scope = @user.company_outreaches
        scope = scope.where(sent_at: @since..) if @since
        total = scope.count
        events = CompanyOutreachEvent.where(company_outreach_id: scope.select(:id))
        reached = {
          "sent" => total,
          "responded" => events.where.not(status: :no_response).distinct.count(:company_outreach_id),
          "interview" => events.where(status: :interview).distinct.count(:company_outreach_id),
          "offer" => events.where(status: :offer).distinct.count(:company_outreach_id)
        }

        { total: total, stages: stages(OUTREACH_STAGES, reached), rejected: events.where(status: :rejected).distinct.count(:company_outreach_id) }
      end

      def reached_by_status(scope)
        JobApplicationEvent.where(job_application_id: scope.select(:id), event_type: :status_changed)
                           .where.not(status: nil).group(:status).distinct.count(:job_application_id)
      end

      # Anything after "applied", including a rejection, is a reply.
      def responded_count(scope)
        JobApplicationEvent.where(job_application_id: scope.select(:id), event_type: :status_changed)
                           .where.not(status: [ nil, :applied ]).distinct.count(:job_application_id)
      end

      def stages(names, reached)
        previous = nil
        names.map do |name|
          count = reached[name] || 0
          stage = { name: name, count: count, of_total: rate(count, reached[names.first]), of_previous: previous && rate(count, previous) }
          previous = count
          stage
        end
      end

      def median_days(scope)
        applied = scope.pluck(:id, :applied_at).to_h
        first_reply = JobApplicationEvent.where(job_application_id: applied.keys, event_type: :status_changed)
                                         .where.not(status: [ nil, :applied ]).group(:job_application_id).minimum(:occurred_at)
        days = first_reply.map { |id, at| (at - applied[id]) / 1.day }.sort
        return nil if days.empty?

        mid = days.size / 2
        (days.size.odd? ? days[mid] : (days[mid - 1] + days[mid]) / 2.0).round(1)
      end

      def rate(part, whole)
        whole.to_i.zero? ? nil : (part.to_f / whole * 100).round(1)
      end
    end
  end
end
