class CreateUserQuestionOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :user_question_orders do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :interview_question, null: false, foreign_key: { on_delete: :cascade }
      t.integer :position, null: false, default: 0

      t.timestamps

      t.index [:user_id, :interview_question_id], unique: true
    end
  end
end
