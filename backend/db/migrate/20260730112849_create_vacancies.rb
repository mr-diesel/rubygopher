class CreateVacancies < ActiveRecord::Migration[8.1]
  def change
    create_table :vacancies do |t|
      t.references :company, null: false, foreign_key: { on_delete: :restrict }
      t.string   :title, null: false
      t.integer  :language, null: false, default: 0 # enum: ruby/go/other
      t.string   :location
      t.integer  :work_mode                         # enum: onsite/hybrid/remote (nil = unknown)
      t.integer  :salary_min
      t.integer  :salary_max
      t.string   :currency
      t.text     :description                        # source text for skill extraction
      t.datetime :published_at                       # source publication date (honest monthly analytics)
      t.datetime :skills_extracted_at                # idempotency marker for the skill-extraction job

      t.timestamps

      t.index [:language, :published_at]
      # Work queue for the extraction job: only rows not analyzed yet.
      t.index :skills_extracted_at, where: "skills_extracted_at IS NULL",
              name: "index_vacancies_pending_skill_extraction"
    end
  end
end
