class AddDateToTrips < ActiveRecord::Migration[8.1]
  def change
    add_column :trips, :date, :date
    add_index :trips, :date
  end
end