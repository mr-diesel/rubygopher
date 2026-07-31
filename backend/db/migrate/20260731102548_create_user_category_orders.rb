class CreateUserCategoryOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :user_category_orders do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :category, null: false
      t.integer :position, null: false, default: 0

      t.timestamps

      t.index [:user_id, :category], unique: true
    end
  end
end
