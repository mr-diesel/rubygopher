class Company < ApplicationRecord
  has_many :vacancies, dependent: :restrict_with_exception
  has_many :job_applications, dependent: :restrict_with_exception
  has_many :company_outreaches, dependent: :restrict_with_exception

  enum :source, { manual: 0, hh: 1, getmatch: 2, habr_career: 3 }

  validates :name, presence: true
end
