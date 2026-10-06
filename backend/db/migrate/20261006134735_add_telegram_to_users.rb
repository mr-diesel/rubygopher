class AddTelegramToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :telegram_chat_id, :bigint, comment: "Telegram chat the notifier delivers to; NULL until the user links the bot"
    add_column :users, :telegram_link_code, :string, comment: "One-time code sent to the bot as /start <code>; cleared once linked"
    add_index :users, :telegram_link_code, unique: true, where: "telegram_link_code IS NOT NULL"
  end
end
