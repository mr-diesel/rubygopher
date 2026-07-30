class CreateCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.string  :name, null: false
      t.string  :website
      t.text    :description
      t.integer :source, null: false, default: 0 # enum: manual/hh/getmatch/habr_career
      t.string  :external_id                      # employer id in the source (nil for manual)

      t.timestamps

      t.index :name
      # Unique per source only for imported companies; manual ones (external_id IS NULL) are exempt.
      t.index [:source, :external_id], unique: true, where: "external_id IS NOT NULL"
    end
  end
end
