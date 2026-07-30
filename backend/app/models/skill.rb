class Skill < ApplicationRecord
  has_many :vacancy_skills, dependent: :destroy
  has_many :vacancies, through: :vacancy_skills
  has_many :user_skills, dependent: :destroy
  has_many :users, through: :user_skills

  enum :category, { language: 0, framework: 1, tool: 2, database: 3, soft: 4 }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
end
