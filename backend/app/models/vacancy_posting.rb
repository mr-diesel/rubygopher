class VacancyPosting < ApplicationRecord
  belongs_to :vacancy

  enum :source, { manual: 0, hh: 1, getmatch: 2, habr_career: 3 }

  validates :external_id, presence: true, uniqueness: { scope: :source }
  validates :url, presence: true
end
