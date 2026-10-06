FactoryBot.define do
  factory :console_session do
    code { "p 1 + 1" }
    context { "ruby" }
  end
end
