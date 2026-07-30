class CompanyOutreach < ApplicationRecord
  belongs_to :user
  belongs_to :company

  has_many :events, class_name: "CompanyOutreachEvent", dependent: :delete_all

  enum :status, { no_response: 0, talent_pool: 1, interview: 2, offer: 3, rejected: 4 }

  validates :sent_at, presence: true
  validates :company_id, uniqueness: { scope: :user_id }
end
