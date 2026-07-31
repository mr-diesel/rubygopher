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
end
