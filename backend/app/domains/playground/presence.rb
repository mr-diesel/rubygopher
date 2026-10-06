module Playground
  # Who is currently subscribed to a shared session. One entry per subscription, so
  # two tabs of the same user count twice. Keys expire so a crashed server cannot
  # leave ghosts forever.
  class Presence
    TTL = 1.day

    def self.join(session, member_id)
      redis.multi do |tx|
        tx.sadd(key(session), member_id)
        tx.expire(key(session), TTL.to_i)
      end
      count(session)
    end

    def self.leave(session, member_id)
      redis.srem(key(session), member_id)
      count(session)
    end

    def self.count(session)
      redis.scard(key(session))
    end

    def self.key(session)
      "console:session:#{session.token}:members"
    end

    def self.redis
      @redis ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
    end
  end
end
