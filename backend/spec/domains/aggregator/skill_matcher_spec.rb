require "rails_helper"

RSpec.describe Aggregator::SkillMatcher do
  let(:rails) { build(:skill, name: "Ruby on Rails", slug: "rails", aliases: [ "Rails", "RoR" ]) }
  let(:go) { build(:skill, name: "Go", slug: "go", aliases: [ "Golang" ]) }
  let(:cpp) { build(:skill, name: "C++", slug: "cpp") }
  let(:node) { build(:skill, name: "Node.js", slug: "node") }

  subject(:matcher) { described_class.new([ rails, go, cpp, node ]) }

  it "matches names and aliases as whole words, ignoring case" do
    expect(matcher.match("Ищем RAILS-разработчика (ror welcome)")).to eq([ rails ])
    expect(matcher.match("Trails and Railsway")).to be_empty
  end

  it "matches short terms case-sensitively so 'go to' is not Go" do
    expect(matcher.match("ready to go to the office")).to be_empty
    expect(matcher.match("backend in Go")).to eq([ go ])
    expect(matcher.match("golang backend")).to eq([ go ])
  end

  it "handles terms with punctuation" do
    expect(matcher.match("C++, Node.js")).to contain_exactly(cpp, node)
    expect(matcher.match("Node and C")).to be_empty
  end

  it "returns nothing for blank text" do
    expect(matcher.match(nil)).to be_empty
  end
end
