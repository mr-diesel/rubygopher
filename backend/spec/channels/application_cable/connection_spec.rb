require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:user) { create(:user) }

  it "identifies the user by the JWT query parameter" do
    token, = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)

    connect "/cable?token=#{token}"

    expect(connection.current_user).to eq(user)
  end

  it "rejects a connection without a valid token" do
    expect { connect "/cable?token=garbage" }.to have_rejected_connection
  end
end
