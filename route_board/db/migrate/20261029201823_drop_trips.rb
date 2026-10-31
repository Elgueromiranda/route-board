class DropTrips < ActiveRecord::Migration[8.1]
  def change
    drop_table :trips
  end
end