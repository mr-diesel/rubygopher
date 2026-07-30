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
end
