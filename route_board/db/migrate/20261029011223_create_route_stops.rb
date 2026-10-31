class CreateRouteStops < ActiveRecord::Migration[8.0]
  def change
    create_table :route_stops, id: false do |t|
      t.string :trip_id, null: false
      t.string :stop_id, null: false
      t.string :departure_time
      t.integer :stop_sequence
    end

    # Performance indexes
    add_index :route_stops, :trip_id
    add_index :route_stops, :stop_id
  end
end