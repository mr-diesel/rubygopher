require "rails_helper"

RSpec.describe "db/seeds.rb" do
  it "loads the skills dictionary idempotently" do
    expect { Rails.application.load_seed }.to change(Skill, :count).from(0)
    expect { Rails.application.load_seed }.not_to change(Skill, :count)
    expect(Skill.find_by!(slug: "rails")).to have_attributes(name: "Ruby on Rails", category: "framework", aliases: [ "Rails", "RoR" ])
  end
end
