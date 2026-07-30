class CreateVacancyPostings < ActiveRecord::Migration[8.1]
  def change
    create_table :vacancy_postings do |t|
      t.references :vacancy, null: false, foreign_key: { on_delete: :cascade }
      t.integer  :source, null: false           # enum: manual/hh/getmatch/habr_career
      t.string   :external_id, null: false       # vacancy id within the source
      t.string   :url, null: false               # direct "apply on the source site" link
      t.jsonb    :raw, null: false, default: {}   # raw source payload (debug, re-extraction)
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
      t.boolean  :active, null: false, default: true

      t.timestamps

      # Dedup within a single source (re-sync must not duplicate the same posting).
      t.index [:source, :external_id], unique: true
    end
  end
end
