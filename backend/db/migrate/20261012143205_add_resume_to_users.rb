class AddResumeToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :resume, :text, comment: "Candidate's résumé as pasted plain text or Markdown; feeds the mock-interview prompt"
  end
end
