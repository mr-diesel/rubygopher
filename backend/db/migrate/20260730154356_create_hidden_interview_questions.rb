class CreateHiddenInterviewQuestions < ActiveRecord::Migration[8.1]
  def change
    create_table :hidden_interview_questions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :interview_question, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps

      t.index [:user_id, :interview_question_id], unique: true
    end
  end
end
