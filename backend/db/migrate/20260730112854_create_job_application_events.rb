class CreateJobApplicationEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :job_application_events do |t|
      # No separate index on job_application_id — the composite index below covers it.
      t.references :job_application, null: false,
                   foreign_key: { on_delete: :cascade }, index: false
      t.integer  :event_type, null: false          # enum: status_changed/note_added/interview_scheduled/follow_up_sent
      t.integer  :status                           # set only for status_changed events
      t.text     :comment                          # human-readable note attached to the event
      t.jsonb    :payload, null: false, default: {} # type-specific structured details
      t.datetime :occurred_at, null: false          # when the fact happened (may differ from created_at)

      # Append-only log: created_at only, no updated_at (records are immutable).
      t.datetime :created_at, null: false

      t.index [:job_application_id, :occurred_at]
    end
  end
end
