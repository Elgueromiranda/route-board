class CreateVehicles < ActiveRecord::Migration[8.1]
  def change
    create_table :vehicles do |t|
      t.string :label
      t.string :status, default: "available", null: false
      t.timestamps
    end
    add_index :vehicles, :status
  end
end