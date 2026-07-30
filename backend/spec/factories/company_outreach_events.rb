FactoryBot.define do
  factory :company_outreach_event do
    company_outreach
    status { :no_response }
    changed_at { Time.current }
  end
end
