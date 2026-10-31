class CreateStops < ActiveRecord::Migration[8.1]
  def change
    create_table :stops,id: false do |t|
      t.string :stop_id, primary_key: true
      t.string :stop_name
      t.string :stop_desc
      t.string :stop_lat
      t.string :stop_lon
    end
  end
end
