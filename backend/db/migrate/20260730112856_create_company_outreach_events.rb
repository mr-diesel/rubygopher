class CreateCompanyOutreachEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :company_outreach_events do |t|
      # No separate index on company_outreach_id — the composite index below covers it.
      t.references :company_outreach, null: false,
                   foreign_key: { on_delete: :cascade }, index: false
      t.integer  :status, null: false   # snapshot of the new status
      t.text     :comment               # note on the status change

      # Narrow audit table: created_at only, no updated_at (records are immutable).
      t.datetime :changed_at, null: false
      t.datetime :created_at, null: false

      t.index [:company_outreach_id, :changed_at]
    end
  end
end
