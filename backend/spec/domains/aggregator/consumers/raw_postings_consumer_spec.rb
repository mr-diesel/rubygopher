require "rails_helper"
require "karafka/testing/rspec/helpers"

RSpec.describe Aggregator::Consumers::RawPostingsConsumer do
  include Karafka::Testing::RSpec::Helpers

  subject(:consumer) { karafka.consumer_for("vacancies.raw") }

  let(:posting) do
    { source: "hh", external_id: "hh-42", url: "https://hh.ru/vacancy/42", title: "Go Engineer", company: { name: "Globex" } }
  end

  it "ingests every message in the batch" do
    karafka.produce(posting.to_json)
    karafka.produce(posting.merge(external_id: "hh-43", title: "Ruby Engineer").to_json)

    consumer.consume

    expect(VacancyPosting.pluck(:external_id)).to contain_exactly("hh-42", "hh-43")
  end

  it "skips an invalid message and keeps going" do
    karafka.produce({ source: "hh" }.to_json)
    karafka.produce(posting.to_json)

    expect { consumer.consume }.not_to raise_error
    expect(VacancyPosting.count).to eq(1)
  end
end
