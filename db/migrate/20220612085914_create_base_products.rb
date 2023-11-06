class CreateBaseProducts < ActiveRecord::Migration[6.0]
  def change
    create_table :base_products do |t|
      t.string :light_id, index: true
      t.string :shopify_variant_id, index: true
      t.string :shopify_product_id, index: true
      t.string :upc, index: true, foreign_key: true
      t.timestamps
    end
  end
end
