require "rails_helper"

RSpec.describe Identity::Authenticate do
  let(:user) { create(:user) }

  it "accepts a portal JWT" do
    token, = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)

    expect(described_class.call(token)).to have_attributes(user: user, method: :jwt)
  end

  it "accepts the personal API token and records its use" do
    token = user.regenerate_api_token!

    expect(described_class.call(token)).to have_attributes(user: user, method: :api_token)
    expect(user.reload.api_token_last_used_at).to be_within(2.seconds).of(Time.current)
  end

  it "rejects a rotated token, garbage and blanks" do
    old = user.regenerate_api_token!
    user.regenerate_api_token!

    expect(described_class.call(old)).to be_nil
    expect(described_class.call("rg_nope")).to be_nil
    expect(described_class.call("not.a.jwt")).to be_nil
    expect(described_class.call("")).to be_nil
  end
end
