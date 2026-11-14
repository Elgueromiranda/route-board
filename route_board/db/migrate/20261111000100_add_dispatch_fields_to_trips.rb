class AddDispatchFieldsToTrips < ActiveRecord::Migration[8.1]
  def change
    add_column :trips, :route_name, :string
    add_column :trips, :destination, :string
    add_column :trips, :vehicle_label, :string
    add_column :trips, :stops_json, :text, null: false, default: "[]"
    add_column :trips, :next_stop_index, :integer, null: false, default: 0
    add_column :trips, :departed, :boolean, null: false, default: false
    add_column :trips, :status, :string, null: false, default: "Scheduled"
  end
end