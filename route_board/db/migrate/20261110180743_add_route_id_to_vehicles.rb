class AddRouteIdToVehicles < ActiveRecord::Migration[8.1]
  def change
    add_column :vehicles, :route_id, :string
    add_index  :vehicles, :route_id, unique: true
  end
end