# Synthetic data for the console sandbox. Everything here is invented: no real
# users, no personal notes, nothing worth protecting. Rebuilt on every stack start.
require "factory_bot_rails"

include FactoryBot::Syntax::Methods

connection = ActiveRecord::Base.connection
role_password = connection.quote(ENV.fetch("SANDBOX_CONSOLE_PASSWORD"))

unless connection.select_value("SELECT 1 FROM pg_roles WHERE rolname = 'console'")
  connection.execute("CREATE ROLE console LOGIN PASSWORD #{role_password}")
end
connection.execute(<<~SQL)
  ALTER ROLE console WITH PASSWORD #{role_password};
  ALTER ROLE console SET default_transaction_read_only = on;
  ALTER ROLE console SET statement_timeout = '5s';
  GRANT CONNECT ON DATABASE #{connection.quote_table_name(connection.current_database)} TO console;
  GRANT USAGE ON SCHEMA public TO console;
  GRANT SELECT ON ALL TABLES IN SCHEMA public TO console;
SQL

user = create(:user, email: "demo@sandbox.local", name: "Demo Seeker")
create(:admin, email: "admin@sandbox.local", password: "password123") if defined?(Admin)

skills = %w[Ruby Rails PostgreSQL Sidekiq Go Kafka Docker React].map { |name| create(:skill, name: name) }

companies = %w[Acme Globex Initech Umbrella Hooli].map.with_index do |name, i|
  create(:company, name: name, source: Company.sources.keys[i % Company.sources.size])
end

vacancies = companies.flat_map do |company|
  [
    create(:vacancy, company: company, title: "Senior Ruby Developer", language: :ruby, work_mode: :remote),
    create(:vacancy, company: company, title: "Go Backend Engineer", language: :go, work_mode: :hybrid)
  ]
end
vacancies.each { |vacancy| skills.sample(3).each { |skill| create(:vacancy_skill, vacancy: vacancy, skill: skill) } }

statuses = JobApplication.statuses.keys
vacancies.first(6).each_with_index do |vacancy, i|
  application = create(:job_application, user: user, vacancy: vacancy, status: statuses[i % statuses.size], applied_at: (i * 3).days.ago)
  create(:job_application_event, job_application: application, event_type: :status_changed, status: application.status, occurred_at: application.applied_at)
end

companies.first(2).each_with_index do |company, i|
  create(:company_outreach, user: user, company: company, status: :no_response, sent_at: (i + 1).weeks.ago)
end

[
  [ "Ruby", "Blocks vs procs", "What is the difference between a block, a proc and a lambda?",
    "Blocks are syntax, not objects. Procs and lambdas are objects; lambdas check arity and `return` locally.",
    "square = ->(x) { x * x }\nsquare.call(4) # => 16" ],
  [ "Rails", "N+1", "How do you detect and fix an N+1 query?",
    "Watch the log for repeated queries, then preload with includes/preload/eager_load.",
    "Post.includes(:comments).each { |post| post.comments.size }" ],
  [ "Go", "Goroutines", "What is a goroutine and how is it different from a thread?",
    "A goroutine is a lightweight green thread scheduled by the Go runtime; thousands are cheap.",
    "go func() { fmt.Println(\"hi\") }()" ]
].each_with_index do |(category, label, question, answer, code), i|
  create(:interview_question, category: category, label: label, question: question, answer: nil, code: nil, language: nil,
                              position: i, body: InterviewQuestion.legacy_to_body(answer, code, category.downcase).to_json)
end

puts "sandbox database seeded: #{User.count} user, #{Company.count} companies, #{Vacancy.count} vacancies, " \
     "#{JobApplication.count} applications, #{InterviewQuestion.count} questions"
