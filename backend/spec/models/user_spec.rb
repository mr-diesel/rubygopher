require "rails_helper"

RSpec.describe User do
  describe "personal API token" do
    let(:user) { create(:user) }

    it "generates a prefixed token and remembers when" do
      token = user.regenerate_api_token!

      expect(token).to start_with("rg_")
      expect(user.api_token_generated_at).to be_within(2.seconds).of(Time.current)
      expect(described_class.find_by_api_token(token)).to eq(user)
    end

    it "is stored encrypted, not in clear text" do
      token = user.regenerate_api_token!
      raw = described_class.connection.select_value("select api_token from users where id = #{user.id}")

      expect(raw).not_to eq(token)
      expect(raw).to include("\"p\":")
    end

    it "rotation invalidates the previous token" do
      old = user.regenerate_api_token!
      user.regenerate_api_token!

      expect(described_class.find_by_api_token(old)).to be_nil
    end

    it "ignores lookups that are not rg_ tokens" do
      expect(described_class.find_by_api_token("")).to be_nil
      expect(described_class.find_by_api_token("abc")).to be_nil
      expect(described_class.find_by_api_token(nil)).to be_nil
    end

    it "revokes" do
      user.regenerate_api_token!
      user.revoke_api_token!

      expect(user.reload.api_token).to be_nil
    end
  end
end
