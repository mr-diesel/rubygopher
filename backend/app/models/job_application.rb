class JobApplication < ApplicationRecord
  belongs_to :user
  belongs_to :company
  belongs_to :vacancy
  belongs_to :via_posting, class_name: "VacancyPosting", optional: true

  has_many :events, class_name: "JobApplicationEvent", dependent: :delete_all

  enum :status, { applied: 0, viewed: 1, screening: 2,
                  tech_interview: 3, offer: 4, rejected: 5 }

  validates :applied_at, presence: true
  validates :vacancy_id, uniqueness: { scope: :user_id }
end
