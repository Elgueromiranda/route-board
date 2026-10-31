class CreateRoutes < ActiveRecord::Migration[8.1]
  def change
    create_table :routes,id: false do |t|
      t.string :route_id, primary_key: true
      t.string :route_short_name
      t.string :route_long_name
      t.string :route_color
    end
  end
end
