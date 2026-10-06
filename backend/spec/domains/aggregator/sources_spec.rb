require "rails_helper"

RSpec.describe Aggregator::Sources do
  it "recognises job-board vacancy links" do
    expect(described_class.parse("https://hh.ru/vacancy/123456?from=search")).to eq(source: "hh", external_id: "123456")
    expect(described_class.parse("https://spb.hh.ru/vacancy/7")).to eq(source: "hh", external_id: "7")
    expect(described_class.parse("https://career.habr.com/vacancies/1000123")).to eq(source: "habr_career", external_id: "1000123")
    expect(described_class.parse("https://getmatch.ru/vacancies/555")).to eq(source: "getmatch", external_id: "555")
    expect(described_class.parse("https://hirify.me/jobs/1212044-senior-backend-engineer-ruby")).to eq(source: "hirify", external_id: "1212044")
  end

  it "returns nil for anything else" do
    expect(described_class.parse("https://acme.io/jobs/1")).to be_nil
    expect(described_class.parse(nil)).to be_nil
  end
end
