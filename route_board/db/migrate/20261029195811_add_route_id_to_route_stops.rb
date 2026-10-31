class AddRouteIdToRouteStops < ActiveRecord::Migration[8.1]
  def change
    add_column :route_stops, :route_id, :string
    add_index  :route_stops, :route_id
    add_index  :route_stops, [:stop_id, :departure_time], name: 'idx_route_stops_stop_dep'
  end
end