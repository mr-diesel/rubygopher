require "rails_helper"

RSpec.describe Playground::RateLimit do
  let(:user) { build_stubbed(:user) }
  let(:redis) { described_class.redis }

  before { redis.del(described_class.key(user)) }

  def drain(user)
    described_class::CAPACITY.times { described_class.consume(user) }
  end

  it "allows a burst up to the capacity" do
    verdicts = Array.new(described_class::CAPACITY) { described_class.consume(user) }

    expect(verdicts).to all(be_allowed)
  end

  it "refuses once the bucket is empty and says when to retry" do
    drain(user)
    verdict = described_class.consume(user)

    expect(verdict).not_to be_allowed
    expect(verdict.retry_after).to be_within(0.1).of(1 / described_class::REFILL_PER_SECOND)
  end

  it "refills over time" do
    drain(user)
    redis.hincrbyfloat(described_class.key(user), "at", -4)

    expect(described_class.consume(user)).to be_allowed
  end

  it "counts users separately" do
    drain(user)

    expect(described_class.consume(build_stubbed(:user))).to be_allowed
  end

  it "reloads the script if Redis dropped it" do
    described_class.consume(user)
    redis.script(:flush)

    expect(described_class.consume(user)).to be_allowed
  end
end
