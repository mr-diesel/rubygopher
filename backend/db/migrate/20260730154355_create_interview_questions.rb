class CreateInterviewQuestions < ActiveRecord::Migration[8.1]
  def change
    create_table :interview_questions do |t|
      # user_id NULL = default question (admin-managed, shared); set = user's own question.
      t.references :user, null: true, foreign_key: { on_delete: :cascade }
      t.string  :label, null: false
      t.text    :question, null: false
      t.text    :answer
      t.text    :code
      t.string  :language
      t.integer :position, null: false, default: 0

      t.timestamps

      t.index [:user_id, :position]
    end
  end
end
