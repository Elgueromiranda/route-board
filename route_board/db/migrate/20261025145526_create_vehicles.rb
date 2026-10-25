class CreateVehicles < ActiveRecord::Migration[8.1]
  def change
    create_table :vehicles do |t|
      t.string :code
      t.string :vehicle_type

      t.timestamps
    end
    add_index :vehicles, :code, unique: true
  end
end
