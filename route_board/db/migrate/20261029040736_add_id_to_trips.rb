class AddIdToTrips < ActiveRecord::Migration[8.1]
  def up
    # 1. Create a new table with the desired structure
    create_table :trips_new do |t|
      t.string :trip_id, null: false
      t.string :route_id
      t.string :service_id
      t.date   :date
    end

    # 2. Copy the old data over
    execute <<~SQL
      INSERT INTO trips_new (trip_id, route_id, service_id, date)
      SELECT trip_id, route_id, service_id, date FROM trips
    SQL

    # 3. Drop the old table
    drop_table :trips

    # 4. Rename the new table to trips
    rename_table :trips_new, :trips

    # 5. Add the indexes you need
    add_index :trips, :trip_id
    add_index :trips, [:trip_id, :date], unique: true
    add_index :trips, :date
    add_index :trips, :route_id
  end

  def down
    # To roll back, simply remove the id column
    # (SQLite supports DROP COLUMN in newer versions)
    remove_column :trips, :id
  end
end