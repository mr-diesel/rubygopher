require "rails_helper"

RSpec.describe Aggregator::Clients::Hh do
  subject(:client) { described_class.new }

  let(:body) do
    {
      id: 123, name: "Senior Ruby Developer", alternate_url: "https://hh.ru/vacancy/123",
      employer: { id: 9, name: "Acme", alternate_url: "https://hh.ru/employer/9" },
      area: { name: "Москва" }, schedule: { id: "remote" }, salary: { from: 300_000, to: nil, currency: "RUR" },
      description: "<p>Rails</p>", published_at: "2026-10-01T10:00:00+0300"
    }
  end

  it "fetches and normalises a vacancy" do
    stub_request(:get, "https://api.hh.ru/vacancies/123").with(headers: { "User-Agent" => /RubyGopher/ }).to_return(status: 200, body: body.to_json)

    expect(client.fetch_vacancy(123)).to include(
      source: "hh", external_id: "123", title: "Senior Ruby Developer", url: "https://hh.ru/vacancy/123",
      company: { name: "Acme", external_id: "9", website: "https://hh.ru/employer/9" },
      location: "Москва", work_mode: "remote", salary_min: 300_000, currency: "RUR"
    )
  end

  it "raises NotFound on 404" do
    stub_request(:get, "https://api.hh.ru/vacancies/1").to_return(status: 404, body: "{}")

    expect { client.fetch_vacancy(1) }.to raise_error(described_class::NotFound)
  end

  it "wraps timeouts and server errors" do
    stub_request(:get, "https://api.hh.ru/vacancies/2").to_timeout
    stub_request(:get, "https://api.hh.ru/vacancies/3").to_return(status: 503)

    expect { client.fetch_vacancy(2) }.to raise_error(described_class::Error, /unavailable/)
    expect { client.fetch_vacancy(3) }.to raise_error(described_class::Error, /503/)
  end
end
