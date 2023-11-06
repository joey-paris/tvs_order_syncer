class CreateProductPayloads < ActiveRecord::Migration[6.0]
  def change
    create_table :product_payloads do |t|
      t.boolean :processed, default: false
      t.jsonb :json_payload
      t.timestamps
    end
  end
end
