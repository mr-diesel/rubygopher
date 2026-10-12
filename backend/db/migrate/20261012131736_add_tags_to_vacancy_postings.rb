class AddTagsToVacancyPostings < ActiveRecord::Migration[8.1]
  def change
    add_column :vacancy_postings, :tags, :jsonb, null: false, default: [],
               comment: "Skill tags exactly as the job board listed them (e.g. [\"Ruby on Rails\", \"PostgreSQL\"]); input for dictionary skill extraction"
  end
end
