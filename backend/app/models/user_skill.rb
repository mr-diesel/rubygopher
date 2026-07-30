class UserSkill < ApplicationRecord
  belongs_to :user
  belongs_to :skill

  # Proficiency level (optional) — used later by the interview trainer's "weak topics".
  enum :level, { beginner: 0, intermediate: 1, advanced: 2 }

  validates :skill_id, uniqueness: { scope: :user_id }
end
