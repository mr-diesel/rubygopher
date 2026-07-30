class JobApplicationEvent < ApplicationRecord
  belongs_to :job_application

  enum :event_type, { status_changed: 0, note_added: 1,
                      interview_scheduled: 2, follow_up_sent: 3 }
  # Prefixed to avoid clashing with JobApplication's status predicates when read together.
  enum :status, { applied: 0, viewed: 1, screening: 2,
                  tech_interview: 3, offer: 4, rejected: 5 }, prefix: :status

  validates :occurred_at, presence: true

  # Append-only log: records are immutable once created.
  def readonly?
    persisted?
  end
end
