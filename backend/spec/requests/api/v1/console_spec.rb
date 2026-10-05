require "rails_helper"

RSpec.describe "API V1 Console", type: :request do
  let(:user) { create(:user, password: "password123") }

  def auth_headers(as_user = user)
    token, = Warden::JWTAuth::UserEncoder.new.call(as_user, :user, nil)
    { "Authorization" => "Bearer #{token}" }
  end

  def run(code, **params)
    post "/api/v1/console/eval", params: { code: code }.merge(params), headers: auth_headers, as: :json
    response.parsed_body
  end

  describe "POST /api/v1/console/eval" do
    it "requires authentication" do
      post "/api/v1/console/eval", params: { code: "1 + 1" }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a blank snippet" do
      post "/api/v1/console/eval", params: { code: "" }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:bad_request)
    end

    it "rejects an unknown context" do
      post "/api/v1/console/eval", params: { code: "1", context: "python" }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:bad_request)
    end

    it "is refused when the console is disabled" do
      allow(Playground::Runner).to receive(:enabled?).and_return(false)

      post "/api/v1/console/eval", params: { code: "1 + 1" }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    context "in the rails context" do
      it "returns what the snippet printed" do
        body = run("p 1 + 1")

        expect(response).to have_http_status(:created)
        expect(body["output"]).to eq("2\n")
        expect(body["error"]).to be_nil
        expect(body["context"]).to eq("rails")
        expect(body["duration_ms"]).to be_a(Integer)
      end

      it "reports nothing for an expression that prints nothing" do
        body = run("1 + 1")

        expect(body["output"]).to eq("")
        expect(body).not_to have_key("value")
      end

      it "captures stdout and stderr alike" do
        body = run("puts 'out'; warn 'err'")

        expect(body["output"]).to eq("out\nerr\n")
      end

      it "has the Rails application loaded" do
        body = run("p Rails.application.class.name")

        expect(body["output"]).to eq("\"Backend::Application\"\n")
      end

      it "reports a raised error instead of failing the request" do
        body = run("raise ArgumentError, 'boom'")

        expect(response).to have_http_status(:created)
        expect(body.dig("error", "class")).to eq("ArgumentError")
        expect(body.dig("error", "message")).to eq("boom")
        expect(body.dig("error", "backtrace")).to be_present
      end

      it "reports a syntax error" do
        body = run("def broken(")

        expect(body.dig("error", "class")).to eq("SyntaxError")
      end

      it "kills a snippet that runs past the timeout" do
        body = run("sleep 5", timeout: 1)

        expect(body.dig("error", "class")).to eq("Timeout")
      end

      it "does not leak state between two runs" do
        run("$leaked = 42")

        expect(run("p $leaked")["output"]).to eq("nil\n")
      end
    end

    context "in the ruby context" do
      # The compose environment points at the sandbox; these examples exercise the local runner.
      before { allow(Playground::Runners::Sandbox).to receive(:url).and_return(nil) }

      it "evaluates plain Ruby" do
        body = run("p [3, 1, 2].sort", context: "ruby")

        expect(body["output"]).to eq("[1, 2, 3]\n")
        expect(body["context"]).to eq("ruby")
      end

      it "runs without Rails loaded" do
        body = run("p defined?(Rails)", context: "ruby")

        expect(body["output"]).to eq("nil\n")
      end

      it "kills a snippet that runs past the timeout" do
        body = run("sleep 5", context: "ruby", timeout: 1)

        expect(body.dig("error", "class")).to eq("Timeout")
      end

      context "with the sandbox configured" do
        before do
          allow(Playground::Runners::Sandbox).to receive(:url).and_return("http://sandbox:8080")
          stub_request(:post, "http://sandbox:8080/eval")
            .to_return(status: 200, body: { output: "from sandbox\n", error: nil }.to_json)
        end

        it "delegates plain Ruby to the sandbox" do
          body = run("p 1", context: "ruby")

          expect(body["output"]).to eq("from sandbox\n")
          expect(body["context"]).to eq("ruby")
        end

        it "keeps the rails context on the local fork" do
          body = run("p 1 + 1")

          expect(body["output"]).to eq("2\n")
          expect(a_request(:post, "http://sandbox:8080/eval")).not_to have_been_made
        end
      end
    end
  end
end
