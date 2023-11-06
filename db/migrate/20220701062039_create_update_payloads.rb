class CreateUpdatePayloads < ActiveRecord::Migration[6.0]
  def change
    create_table :update_payloads do |t|
      t.jsonb :json_payload
      t.boolean :processed, default: false
      t.timestamps
    end
  end
end
