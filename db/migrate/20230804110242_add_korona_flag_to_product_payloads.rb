class AddKoronaFlagToProductPayloads < ActiveRecord::Migration[6.0]
  def change
    add_column :product_payloads, :korona_flag, :boolean, default: false
  end
end
