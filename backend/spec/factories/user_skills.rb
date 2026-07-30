FactoryBot.define do
  factory :user_skill do
    user
    skill
    level { :intermediate }
  end
end
