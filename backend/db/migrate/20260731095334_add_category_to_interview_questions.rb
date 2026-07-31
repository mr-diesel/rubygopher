class AddCategoryToInterviewQuestions < ActiveRecord::Migration[8.1]
  def change
    add_column :interview_questions, :category, :string, null: false, default: "General"
  end
end
