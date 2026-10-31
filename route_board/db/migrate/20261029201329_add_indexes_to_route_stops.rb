class AddIndexesToRouteStops < ActiveRecord::Migration[8.1]
  def change
    unless index_exists?(:route_stops, :departure_time)
      add_index :route_stops, :departure_time
    end

    unless index_exists?(:route_stops, [:stop_id, :departure_time], name: 'idx_route_stops_stop_dep')
      add_index :route_stops, [:stop_id, :departure_time], name: 'idx_route_stops_stop_dep'
    end
  end
end