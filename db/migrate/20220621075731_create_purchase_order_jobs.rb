class CreatePurchaseOrderJobs < ActiveRecord::Migration[6.0]
  def change
    create_table :purchase_order_jobs do |t|
      t.string :order_id
      t.boolean :completed, default: false
      t.timestamps
    end
  end
end
