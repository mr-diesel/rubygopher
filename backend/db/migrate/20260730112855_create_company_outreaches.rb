class CreateCompanyOutreaches < ActiveRecord::Migration[8.1]
  def change
    create_table :company_outreaches do |t|
      # No separate index on user_id — the composite unique index below covers it.
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :company, null: false, foreign_key: { on_delete: :restrict }
      t.integer  :status, null: false, default: 0 # enum: no_response/talent_pool/interview/offer/rejected
      t.datetime :sent_at, null: false             # when the email was sent
      t.text     :notes

      t.timestamps

      # Can't write to the same company twice (direct outreach without a vacancy).
      t.index [:user_id, :company_id], unique: true
    end
  end
end
