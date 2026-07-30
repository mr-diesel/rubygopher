FactoryBot.define do
  factory :vacancy_posting do
    vacancy
    source { :hh }
    sequence(:external_id) { |n| "ext-#{n}" }
    url { "https://hh.ru/vacancy/1" }
    first_seen_at { Time.current }
    last_seen_at { Time.current }
  end
end
