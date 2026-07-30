class CompanyOutreachEvent < ApplicationRecord
  belongs_to :company_outreach

  enum :status, { no_response: 0, talent_pool: 1, interview: 2, offer: 3, rejected: 4 }

  validates :changed_at, presence: true

  # Append-only audit log: records are immutable once created.
  def readonly?
    persisted?
  end
end
