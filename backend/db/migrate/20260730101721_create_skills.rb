class CreateSkills < ActiveRecord::Migration[8.1]
  def change
    create_table :skills do |t|
      t.string  :name, null: false
      t.string  :slug, null: false
      t.jsonb   :aliases, null: false, default: [] # alternative spellings for matching, e.g. ["RoR","Rails"]
      t.integer :category, null: false, default: 0 # enum: language/framework/tool/database/soft

      t.timestamps

      t.index :slug, unique: true
    end
  end
end
