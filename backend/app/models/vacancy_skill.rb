class VacancySkill < ApplicationRecord
  belongs_to :vacancy
  belongs_to :skill

  # How the skill was derived from the vacancy description.
  enum :source, { manual: 0, dictionary: 1 }

  validates :skill_id, uniqueness: { scope: :vacancy_id }
end
