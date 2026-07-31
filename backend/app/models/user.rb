class User < ApplicationRecord
  # JWT-based auth for the React portal. JTIMatcher stores a jti in the users table;
  # a token is valid while its jti claim matches the column. Logout rotates the jti,
  # invalidating all previously issued tokens for this user.
  include Devise::JWT::RevocationStrategies::JTIMatcher

  # No :rememberable (JWT, not a session cookie).
  devise :database_authenticatable, :registerable,
         :recoverable, :validatable, :trackable,
         :jwt_authenticatable, jwt_revocation_strategy: self

  has_many :user_skills, dependent: :destroy
  has_many :skills, through: :user_skills
  has_many :job_applications, dependent: :destroy
  has_many :company_outreaches, dependent: :destroy
  has_many :interview_questions, dependent: :destroy
  has_many :hidden_interview_questions, dependent: :destroy
  has_many :user_question_orders, dependent: :destroy
  has_many :user_category_orders, dependent: :destroy

  # Persist a personal ordering of questions within a category.
  def reorder_questions!(ordered_ids)
    transaction do
      ordered_ids.each_with_index do |question_id, index|
        order = user_question_orders.find_or_initialize_by(interview_question_id: question_id)
        order.update!(position: index)
      end
    end
  end

  # Persist a personal ordering of categories (by name).
  def reorder_categories!(ordered_names)
    transaction do
      ordered_names.each_with_index do |name, index|
        order = user_category_orders.find_or_initialize_by(category: name)
        order.update!(position: index)
      end
    end
  end
end
