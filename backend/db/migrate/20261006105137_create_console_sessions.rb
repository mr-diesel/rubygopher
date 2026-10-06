class CreateConsoleSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :console_sessions, comment: "Shared live-console sessions: anyone with the token edits the same snippet" do |t|
      t.string :token, null: false, comment: "URL-safe identifier shared as ?session=<token>"
      t.text :code, null: false, default: "", comment: "Current snippet; last write wins"
      t.string :context, null: false, default: "rails", comment: "rails | ruby | go"
      t.jsonb :result, comment: "Last evaluation result as returned by the console API, plus who ran it"

      t.timestamps
    end
    add_index :console_sessions, :token, unique: true
  end
end
