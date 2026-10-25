class CreateTripEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :trip_events do |t|
      t.references :trip, null: false, foreign_key: true
      t.string :event_type
      t.references :stop, null: false, foreign_key: true
      t.datetime :observed_time
      t.integer :delay_delta_minutes
      t.text :notes

      t.timestamps
    end
  end
end
