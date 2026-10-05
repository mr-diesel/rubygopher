module Playground
  # Token bucket per user, kept in Redis and updated atomically by a Lua script:
  # read, refill and spend happen in one step, so concurrent requests cannot
  # both pass on the last token.
  class RateLimit
    CAPACITY = 10          # burst
    REFILL_PER_SECOND = 0.5 # sustained: 30 per minute

    Verdict = Data.define(:allowed, :retry_after) do
      def allowed? = allowed
    end

    SCRIPT = <<~LUA
      local capacity, rate = tonumber(ARGV[1]), tonumber(ARGV[2])
      local time = redis.call('TIME')
      local now = tonumber(time[1]) + tonumber(time[2]) / 1e6
      local state = redis.call('HMGET', KEYS[1], 'tokens', 'at')
      local tokens = tonumber(state[1]) or capacity
      local at = tonumber(state[2]) or now

      tokens = math.min(capacity, tokens + (now - at) * rate)
      local allowed = tokens >= 1
      if allowed then tokens = tokens - 1 end

      redis.call('HSET', KEYS[1], 'tokens', tokens, 'at', now)
      redis.call('EXPIRE', KEYS[1], math.ceil(capacity / rate))
      local retry_after = allowed and 0 or (1 - tokens) / rate
      return { allowed and 1 or 0, tostring(retry_after) }
    LUA

    def self.consume(user)
      allowed, retry_after = evaluate(keys: [ key(user) ], argv: [ CAPACITY, REFILL_PER_SECOND ])
      Verdict.new(allowed: allowed == 1, retry_after: retry_after.to_f)
    end

    def self.key(user)
      "console:bucket:#{user.id}"
    end

    def self.evaluate(**args)
      redis.evalsha(sha, **args)
    rescue Redis::CommandError => e
      raise unless e.message.start_with?("NOSCRIPT")

      @sha = nil
      redis.evalsha(sha, **args)
    end

    def self.sha
      @sha ||= redis.script(:load, SCRIPT)
    end

    def self.redis
      @redis ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
    end
  end
end
