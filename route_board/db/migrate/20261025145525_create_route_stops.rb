class CreateRouteStops < ActiveRecord::Migration[8.1]
  def change
    create_table :route_stops do |t|
      t.references :route, null: false, foreign_key: true
      t.references :stop, null: false, foreign_key: true
      t.integer :sequence_order
      t.integer :baseline_travel_time_minutes
      t.integer :dwell_time_minutes

      t.timestamps
    end
  end
end
