class CreateVacancySkills < ActiveRecord::Migration[8.1]
  def change
    create_table :vacancy_skills do |t|
      # No separate index on vacancy_id — the composite unique index below covers it.
      t.references :vacancy, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :skill, null: false, foreign_key: { on_delete: :cascade }
      t.integer :source, null: false, default: 0 # enum: manual/dictionary (how the skill was derived)

      t.timestamps

      t.index [:vacancy_id, :skill_id], unique: true
    end
  end
end
