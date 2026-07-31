FactoryBot.define do
  factory :interview_question do
    sequence(:label) { |n| "Q#{n}" }
    question { "What is the difference between a block, a proc and a lambda?" }
    answer { "Blocks are not objects; procs and lambdas are. Lambdas check arity and return locally." }
    code { "square = ->(x) { x * x }\nsquare.call(4) # => 16" }
    language { "ruby" }

    trait :owned do
      user
    end
  end
end
