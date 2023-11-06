class AddSkuToBaseProducts < ActiveRecord::Migration[6.0]
  def change
    add_column :base_products, :sku, :string
  end
end
