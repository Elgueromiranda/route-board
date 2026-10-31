class FixTripsPrimaryKey < ActiveRecord::Migration[8.1]
  def change
    # Recreate trips table with trip_id explicitly set as the primary key
    drop_table :trips, if_exists: true

    create_table :trips, primary_key: "trip_id", id: :string, force: :cascade do |t|
      t.string "route_id"
      t.string "service_id"
      t.date "date"
    end

    add_index :trips, :route_id
    add_index :trips, :date
  end
end