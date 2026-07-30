class CreateUserSkills < ActiveRecord::Migration[8.1]
  def change
    create_table :user_skills do |t|
      # No separate index on user_id — the composite unique index below covers it.
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :skill, null: false, foreign_key: { on_delete: :cascade }
      t.integer :level # enum: beginner/intermediate/advanced (nil = unspecified)

      t.timestamps

      t.index [:user_id, :skill_id], unique: true
    end
  end
end
