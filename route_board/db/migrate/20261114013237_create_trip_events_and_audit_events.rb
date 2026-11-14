class CreateTripEventsAndAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :trip_events do |t|
      t.string   :gtfs_trip_id, null: false          # = route_stops.trip_id
      t.string   :event_type,   null: false          # departure/arrived/delayed/canceled/vehicle
      t.string   :stop_id
      t.datetime :occurred_at,  null: false
      t.integer  :delay_minutes, default: 0, null: false
      t.json     :payload
      t.bigint   :sequence, null: false
      t.string   :actor
      t.timestamps
    end
    add_index :trip_events, :sequence, unique: true
    add_index :trip_events, [:gtfs_trip_id, :sequence]

    create_table :audit_events do |t|
      t.string :actor,        null: false
      t.string :action,       null: false
      t.string :subject_type, null: false
      t.string :subject_id,   null: false
      t.json   :changes
      t.timestamps
    end
    add_index :audit_events, [:subject_type, :subject_id]
  end
end