class UserCategoryOrder < ApplicationRecord
  belongs_to :user

  validates :category, uniqueness: { scope: :user_id }
end
