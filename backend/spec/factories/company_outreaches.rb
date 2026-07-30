FactoryBot.define do
  factory :company_outreach do
    user
    company
    status { :no_response }
    sent_at { Time.current }
  end
end
