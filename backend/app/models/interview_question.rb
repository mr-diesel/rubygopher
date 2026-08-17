class InterviewQuestion < ApplicationRecord
  belongs_to :user, optional: true
  has_many :hidden_interview_questions, dependent: :destroy
  has_many :user_question_orders, dependent: :destroy

  validates :label, :question, :category, presence: true

  scope :defaults, -> { where(user_id: nil) }
  scope :ordered, -> { order(:position, :id) }

  # Questions visible to a user: non-hidden defaults + the user's own.
  scope :visible_to, ->(user) {
    hidden = HiddenInterviewQuestion.where(user_id: user.id).select(:interview_question_id)
    where(user_id: [nil, user.id]).where.not(id: hidden).ordered
  }

  def default?
    user_id.nil?
  end

  # Build a TipTap document (JSON string) from legacy answer/code/language fields.
  def self.legacy_to_body(answer, code, language)
    content = []

    answer.to_s.split(/\n{2,}/).each do |para|
      next if para.strip.empty?

      nodes = []
      para.split("\n").each_with_index do |line, i|
        nodes << { type: "hardBreak" } if i.positive?
        nodes << { type: "text", text: line } unless line.empty?
      end
      content << { type: "paragraph", content: nodes }
    end

    if code.present?
      content << { type: "codeBlock", attrs: { language: language }, content: [{ type: "text", text: code }] }
    end

    content << { type: "paragraph" } if content.empty?
    { type: "doc", content: content }.to_json
  end
end
