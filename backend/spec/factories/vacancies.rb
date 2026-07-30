FactoryBot.define do
  factory :vacancy do
    company
    sequence(:title) { |n| "Ruby Developer #{n}" }
    language { :ruby }
  end
end
