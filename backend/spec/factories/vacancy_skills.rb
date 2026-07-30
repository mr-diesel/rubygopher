FactoryBot.define do
  factory :vacancy_skill do
    vacancy
    skill
    source { :manual }
  end
end
