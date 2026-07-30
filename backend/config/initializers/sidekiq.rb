# Sidekiq connects to Redis via REDIS_URL (set per-service in docker-compose).
# Both the client (enqueuing side, e.g. the web process) and the server (worker
# process) must point at the same Redis instance.

redis_config = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

Sidekiq.configure_server do |config|
  config.redis = redis_config
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end
