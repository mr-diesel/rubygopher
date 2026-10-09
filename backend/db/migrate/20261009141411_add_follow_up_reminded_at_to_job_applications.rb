class AddFollowUpRemindedAtToJobApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :job_applications, :follow_up_reminded_at, :datetime,
               comment: "When the reminder for the current next_follow_up_at was sent; a new follow-up date resets the cycle"
  end
end
