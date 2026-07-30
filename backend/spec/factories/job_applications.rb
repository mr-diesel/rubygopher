FactoryBot.define do
  factory :job_application do
    user
    vacancy
    # company is denormalized — keep it consistent with the vacancy.
    company { vacancy.company }
    status { :applied }
    applied_at { Time.current }
  end
end
