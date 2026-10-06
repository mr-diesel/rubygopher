class ConsoleSession < ApplicationRecord
  TOKEN_LENGTH = 12
  TTL = 7.days # since the last edit or run

  validates :context, inclusion: { in: Playground::Runner::CONTEXTS }
  validates :code, length: { maximum: Playground::Runner::MAX_CODE_LENGTH }

  before_validation { self.token ||= SecureRandom.base58(TOKEN_LENGTH) }

  scope :active, -> { where(updated_at: TTL.ago..) }
  scope :stale, -> { where(updated_at: ...TTL.ago) }

  def self.channel
    Playground::Channels::ConsoleSessionChannel
  end

  def state
    { token: token, code: code, context: context, result: result }
  end

  def apply!(code:, context:, by:)
    update!(code: code, context: context)
    broadcast(type: "state", code: code, context: context, by: by)
  end

  def record_run!(result, by:)
    update!(result: result.merge(by: by))
    broadcast(type: "result", result: self.result)
  end

  def broadcast(payload)
    self.class.channel.broadcast_to(self, payload)
  end
end
