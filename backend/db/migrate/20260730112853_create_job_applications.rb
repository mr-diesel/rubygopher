class CreateJobApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :job_applications do |t|
      # No separate index on user_id — the composite indexes below cover it.
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      # company_id is denormalized (always present) for company analytics without a join.
      t.references :company, null: false, foreign_key: { on_delete: :restrict }
      t.references :vacancy, null: false, foreign_key: { on_delete: :restrict }
      # Which posting/source the user applied through (nullified if the posting is purged).
      t.references :via_posting, null: true,
                   foreign_key: { to_table: :vacancy_postings, on_delete: :nullify }
      t.string   :apply_url                          # snapshot of the apply link at apply time
      t.integer  :status, null: false, default: 0    # enum: applied/viewed/screening/tech_interview/offer/rejected
      t.datetime :applied_at, null: false
      t.datetime :last_activity_at                   # last event time (basis for follow-up)
      t.datetime :next_follow_up_at                  # when to remind (nil = no reminder)
      t.datetime :archived_at                        # soft-close (nil = active)

      t.timestamps

      t.index [:user_id, :status]                    # funnel, "my applications in status X"
      t.index [:user_id, :vacancy_id], unique: true  # can't apply to the same vacancy twice
      # Follow-up job scans only live applications awaiting a reminder.
      t.index :next_follow_up_at,
              where: "archived_at IS NULL AND next_follow_up_at IS NOT NULL",
              name: "index_job_applications_pending_follow_up"
    end
  end
end
