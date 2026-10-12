require "rails_helper"

RSpec.describe Identity::Operations::UpdateProfile do
  let(:user) { create(:user, name: "Old") }

  it "updates the name and the résumé" do
    result = described_class.new.call(user, { name: "New", resume: "# Me" })

    expect(result).to be_success
    expect(user.reload).to have_attributes(name: "New", resume: "# Me")
  end

  it "rejects an oversized résumé without writing" do
    result = described_class.new.call(user, { resume: "x" * 20_001 })

    expect(result.failure.first).to eq(:invalid)
    expect(result.failure.last).to have_key(:resume)
    expect(user.reload.resume).to be_nil
  end
end
