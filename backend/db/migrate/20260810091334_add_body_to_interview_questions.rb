class AddBodyToInterviewQuestions < ActiveRecord::Migration[8.1]
  def up
    add_column :interview_questions, :body, :text

    InterviewQuestion.reset_column_information
    InterviewQuestion.find_each do |q|
      q.update_column(:body, InterviewQuestion.legacy_to_body(q.answer, q.code, q.language))
    end
  end

  def down
    remove_column :interview_questions, :body
  end
end
