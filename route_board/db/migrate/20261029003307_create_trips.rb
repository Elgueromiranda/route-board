class CreateTrips < ActiveRecord::Migration[8.1]
  def change
    create_table :trips,id: false do |t|
      t.string :route_id
      t.string :service_id
      t.string :trip_id

    end
  end
end
