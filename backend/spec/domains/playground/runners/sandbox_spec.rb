require "rails_helper"

RSpec.describe Playground::Runners::Sandbox do
  let(:url) { "http://sandbox:8080" }
  let(:token) { nil }

  before do
    allow(described_class).to receive_messages(url: url, token: token)
  end

  describe ".configured?" do
    it "is true when SANDBOX_URL is set" do
      expect(described_class).to be_configured
    end

    context "without SANDBOX_URL" do
      let(:url) { nil }

      it "is false" do
        expect(described_class).not_to be_configured
      end
    end
  end

  describe ".call" do
    subject(:result) { described_class.call("p 1 + 1", context: "rails", timeout: 3) }

    context "when the sandbox answers" do
      before do
        stub_request(:post, "#{url}/eval")
          .with(body: { code: "p 1 + 1", context: "rails", timeout: 3 })
          .to_return(status: 200, body: { output: "2\n", error: nil, context: "rails", duration_ms: 12 }.to_json)
      end

      it "returns only output and error" do
        expect(result).to eq(output: "2\n", error: nil)
      end
    end

    context "with a shared token" do
      let(:token) { "secret" }

      before { stub_request(:post, "#{url}/eval").to_return(status: 200, body: { output: "", error: nil }.to_json) }

      it "sends it as a bearer token" do
        result

        expect(a_request(:post, "#{url}/eval").with(headers: { "Authorization" => "Bearer secret" })).to have_been_made
      end
    end

    context "when the snippet raised inside the sandbox" do
      before do
        stub_request(:post, "#{url}/eval")
          .to_return(status: 200, body: { output: "", error: { class: "ArgumentError", message: "boom", backtrace: [] } }.to_json)
      end

      it "passes the structured error through" do
        expect(result.dig(:error, :class)).to eq("ArgumentError")
      end
    end

    context "when the sandbox rejects the request" do
      before { stub_request(:post, "#{url}/eval").to_return(status: 503, body: { error: "sandbox is busy" }.to_json) }

      it "reports a ConsoleError with the status" do
        expect(result.dig(:error, :class)).to eq("ConsoleError")
        expect(result.dig(:error, :message)).to include("503")
      end
    end

    context "when the sandbox is down" do
      before { stub_request(:post, "#{url}/eval").to_raise(Errno::ECONNREFUSED) }

      it "reports SandboxUnavailable instead of raising" do
        expect(result.dig(:error, :class)).to eq("SandboxUnavailable")
      end
    end

    context "when the connection hangs" do
      before { stub_request(:post, "#{url}/eval").to_timeout }

      it "reports SandboxUnavailable" do
        expect(result.dig(:error, :class)).to eq("SandboxUnavailable")
      end
    end
  end
end
