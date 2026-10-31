class AddServiceIdToRouteStops < ActiveRecord::Migration[8.1]
  def change
    add_column :route_stops, :service_id, :string
    add_index  :route_stops, [:service_id, :departure_time], name: 'idx_route_stops_service_dep'
  end
end