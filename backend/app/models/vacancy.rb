class Vacancy < ApplicationRecord
  belongs_to :company

  has_many :postings, class_name: "VacancyPosting", dependent: :destroy
  has_many :vacancy_skills, dependent: :destroy
  has_many :skills, through: :vacancy_skills
  has_many :job_applications, dependent: :restrict_with_exception

  enum :language, { ruby: 0, go: 1, other: 2 }
  # Column is work_mode (not "remote") to avoid an enum predicate clashing with the value name.
  enum :work_mode, { onsite: 0, hybrid: 1, remote: 2 }

  validates :title, presence: true
end
