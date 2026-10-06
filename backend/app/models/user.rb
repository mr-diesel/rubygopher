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

  # Shown in the cabinet, so it is encrypted rather than hashed; deterministic so find_by works.
  encrypts :api_token, deterministic: true

  API_TOKEN_PREFIX = "rg_".freeze

  def self.find_by_api_token(raw)
    return unless raw.is_a?(String) && raw.start_with?(API_TOKEN_PREFIX)

    find_by(api_token: raw)
  end

  def regenerate_api_token!
    update!(api_token: API_TOKEN_PREFIX + SecureRandom.base58(32), api_token_generated_at: Time.current, api_token_last_used_at: nil)
    api_token
  end

  def revoke_api_token!
    update!(api_token: nil, api_token_generated_at: nil, api_token_last_used_at: nil)
  end

  def touch_api_token!
    update_column(:api_token_last_used_at, Time.current)
  end

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
