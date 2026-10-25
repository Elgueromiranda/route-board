class CreateTrips < ActiveRecord::Migration[8.1]
  def change
    create_table :trips do |t|
      t.references :route, null: false, foreign_key: true
      t.references :vehicle, null: false, foreign_key: true
      t.datetime :scheduled_departure_time
      t.string :status
      t.integer :current_delay_minutes
      t.integer :lock_version

      t.timestamps
    end
  end
end
