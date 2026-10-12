# Idempotent: rerun with bin/rails db:seed after editing the dictionary, then null
# vacancies.skills_extracted_at to have the extract_skills cron re-tag everything.
skills = [
  # language
  [ "ruby", "Ruby", :language, [] ],
  [ "go", "Go", :language, %w[Golang] ],
  [ "javascript", "JavaScript", :language, %w[JS] ],
  [ "typescript", "TypeScript", :language, %w[TS] ],
  [ "python", "Python", :language, [] ],
  [ "sql", "SQL", :language, [] ],
  # framework
  [ "rails", "Ruby on Rails", :framework, [ "Rails", "RoR" ] ],
  [ "sinatra", "Sinatra", :framework, [] ],
  [ "hanami", "Hanami", :framework, [] ],
  [ "grape", "Grape", :framework, [] ],
  [ "rspec", "RSpec", :framework, [] ],
  [ "sidekiq", "Sidekiq", :framework, [] ],
  [ "hotwire", "Hotwire", :framework, %w[Turbo Stimulus] ],
  [ "react", "React", :framework, [ "React.js", "ReactJS" ] ],
  [ "vue", "Vue", :framework, [ "Vue.js", "VueJS" ] ],
  [ "graphql", "GraphQL", :framework, [] ],
  [ "grpc", "gRPC", :framework, [] ],
  [ "gin", "Gin", :framework, [] ],
  # tool
  [ "docker", "Docker", :tool, [] ],
  [ "kubernetes", "Kubernetes", :tool, %w[k8s] ],
  [ "kafka", "Kafka", :tool, [ "Apache Kafka" ] ],
  [ "rabbitmq", "RabbitMQ", :tool, [] ],
  [ "nats", "NATS", :tool, [] ],
  [ "git", "Git", :tool, [] ],
  [ "linux", "Linux", :tool, [] ],
  [ "nginx", "Nginx", :tool, [] ],
  [ "terraform", "Terraform", :tool, [] ],
  [ "ansible", "Ansible", :tool, [] ],
  [ "aws", "AWS", :tool, [ "Amazon Web Services" ] ],
  [ "gcp", "Google Cloud", :tool, %w[GCP] ],
  [ "prometheus", "Prometheus", :tool, [] ],
  [ "grafana", "Grafana", :tool, [] ],
  [ "ci-cd", "CI/CD", :tool, [ "GitLab CI", "GitHub Actions" ] ],
  # database
  [ "postgresql", "PostgreSQL", :database, %w[Postgres] ],
  [ "mysql", "MySQL", :database, [] ],
  [ "redis", "Redis", :database, [] ],
  [ "clickhouse", "ClickHouse", :database, [] ],
  [ "mongodb", "MongoDB", :database, %w[Mongo] ],
  [ "elasticsearch", "Elasticsearch", :database, %w[OpenSearch] ],
  # soft
  [ "english", "English", :soft, [ "английский" ] ],
  [ "agile", "Agile", :soft, %w[Scrum Kanban] ]
]

Skill.upsert_all(
  skills.map { |slug, name, category, aliases| { slug:, name:, category: Skill.categories.fetch(category), aliases: } },
  unique_by: :slug, record_timestamps: true
)
