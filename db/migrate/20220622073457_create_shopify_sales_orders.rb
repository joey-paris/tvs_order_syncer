class CreateShopifySalesOrders < ActiveRecord::Migration[6.0]
  def change
    create_table :shopify_sales_orders do |t|
      t.jsonb :sale_order, null: false
      t.string :purchase_order_id, null: false
      t.string :sales_order_id, null: false
      t.boolean :completed, default: false
      t.timestamps
    end
  end
end
