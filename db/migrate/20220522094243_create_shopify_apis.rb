class CreateShopifyApis < ActiveRecord::Migration[6.0]
  def change
    create_table :shopify_apis do |t|
      t.string :client_id
      t.string :client_secret
      t.string :auth_key
      t.string :refresh
      t.string :account
      t.timestamps
    end
  end
end
