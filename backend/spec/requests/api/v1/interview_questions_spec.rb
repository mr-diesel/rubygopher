require "rails_helper"

RSpec.describe "API V1 Interview Questions", type: :request do
  let(:user) { create(:user, password: "password123") }

  def auth_headers(as_user = user)
    token, = Warden::JWTAuth::UserEncoder.new.call(as_user, :user, nil)
    { "Authorization" => "Bearer #{token}" }
  end

  describe "GET /api/v1/interview_questions" do
    it "returns non-hidden defaults plus the user's own questions" do
      default_q = create(:interview_question)
      own_q = create(:interview_question, user: user)

      hidden = create(:interview_question)
      create(:hidden_interview_question, user: user, interview_question: hidden)
      create(:interview_question, user: create(:user))

      get "/api/v1/interview_questions", headers: auth_headers

      expect(response).to have_http_status(:ok)
      ids = response.parsed_body.map { |q| q["id"] }
      expect(ids).to contain_exactly(default_q.id, own_q.id)
    end

    it "requires authentication" do
      get "/api/v1/interview_questions"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/interview_questions" do
    it "creates the user's own question" do
      expect {
        post "/api/v1/interview_questions",
             params: { label: "GC", question: "How does Ruby GC work?", code: "GC.stat", language: "ruby" },
             headers: auth_headers, as: :json
      }.to change(user.interview_questions, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["editable"]).to be(true)
    end
  end

  describe "PATCH /api/v1/interview_questions/:id" do
    it "updates the user's own code" do
      q = create(:interview_question, user: user)

      patch "/api/v1/interview_questions/#{q.id}", params: { code: "puts 42" }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(q.reload.code).to eq("puts 42")
    end

    it "cannot touch a default question" do
      q = create(:interview_question)

      patch "/api/v1/interview_questions/#{q.id}", params: { code: "x" }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/interview_questions/:id" do
    it "deletes the user's own question" do
      q = create(:interview_question, user: user)

      delete "/api/v1/interview_questions/#{q.id}", headers: auth_headers

      expect(response).to have_http_status(:no_content)
      expect(InterviewQuestion.exists?(q.id)).to be(false)
    end
  end

  describe "POST /api/v1/interview_questions/:id/hide" do
    it "hides a default question from the list" do
      q = create(:interview_question)

      post "/api/v1/interview_questions/#{q.id}/hide", headers: auth_headers
      expect(response).to have_http_status(:no_content)

      get "/api/v1/interview_questions", headers: auth_headers
      expect(response.parsed_body.map { |x| x["id"] }).not_to include(q.id)
    end
  end

  describe "PATCH /api/v1/interview_questions/reorder" do
    it "persists a personal order used in the list" do
      q1 = create(:interview_question, user: user)
      q2 = create(:interview_question, user: user)

      patch "/api/v1/interview_questions/reorder",
            params: { ordered_ids: [q2.id, q1.id] }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:no_content)

      get "/api/v1/interview_questions", headers: auth_headers
      positions = response.parsed_body.to_h { |q| [q["id"], q["position"]] }
      expect(positions[q2.id]).to eq(0)
      expect(positions[q1.id]).to eq(1)
    end
  end
end
