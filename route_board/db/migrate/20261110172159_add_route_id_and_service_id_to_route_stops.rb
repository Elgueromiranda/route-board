class AddRouteIdAndServiceIdToRouteStops < ActiveRecord::Migration[8.1]
  def change
    add_column :route_stops, :route_id,   :string
    add_column :route_stops, :service_id, :string
    add_index  :route_stops, :route_id
    add_index  :route_stops, :service_id
  end
end