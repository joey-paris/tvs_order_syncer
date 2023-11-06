class CreateLightApis < ActiveRecord::Migration[6.0]
  def change
    create_table :light_apis do |t|
      t.string :client_id
      t.string :client_secret
      t.string :refresh
      t.string :account
      t.string :light_key
      t.timestamps
    end
  end
end
