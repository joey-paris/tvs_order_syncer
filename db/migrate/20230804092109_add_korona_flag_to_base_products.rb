class AddKoronaFlagToBaseProducts < ActiveRecord::Migration[6.0]
  def change
    add_column :base_products, :korona_flag, :boolean, default: false
  end
end
