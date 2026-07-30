FactoryBot.define do
  factory :skill do
    sequence(:name) { |n| "Skill #{n}" }
    sequence(:slug) { |n| "skill-#{n}" }
    category { :language }
  end
end
