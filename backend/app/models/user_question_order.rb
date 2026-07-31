class UserQuestionOrder < ApplicationRecord
  belongs_to :user
  belongs_to :interview_question

  validates :interview_question_id, uniqueness: { scope: :user_id }
end
