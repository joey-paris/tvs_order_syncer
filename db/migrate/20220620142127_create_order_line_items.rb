class CreateOrderLineItems < ActiveRecord::Migration[6.0]
  def change
    create_table :order_line_items do |t|
      t.references :base_product, index: true, foreign_key: true
      t.string :shop_id, null: false
      t.string :order_id, null: false
      t.string :quantity, null: false
      t.string :order_line_item_id, null: false
      t.timestamps
    end
  end
end
