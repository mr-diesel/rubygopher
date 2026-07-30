class Admin < ApplicationRecord
  # Session-based auth for the Slim admin panel.
  # No :registerable — admins are created via console/seeds, not public sign-up.
  devise :database_authenticatable, :recoverable,
         :rememberable, :validatable, :trackable
end
