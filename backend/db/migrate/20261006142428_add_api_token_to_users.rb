class AddApiTokenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :api_token, :string, comment: "Personal token for external AI assistants (rg_...), encrypted deterministically so it can be looked up"
    add_column :users, :api_token_generated_at, :datetime
    add_column :users, :api_token_last_used_at, :datetime, comment: "Touched on every authenticated API call; a surprise here is the cue to rotate"
    add_index :users, :api_token, unique: true, where: "api_token IS NOT NULL"
  end
end
