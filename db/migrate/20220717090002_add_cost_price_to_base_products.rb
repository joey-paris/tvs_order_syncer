class AddCostPriceToBaseProducts < ActiveRecord::Migration[6.0]
  def change
    add_column :base_products, :cost, :string
    add_column :base_products, :price, :string
  end
end
