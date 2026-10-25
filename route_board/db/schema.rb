# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_25_145529) do
  create_table "audit_events", force: :cascade do |t|
    t.string "actor_role"
    t.string "action"
    t.text "details"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "route_stops", force: :cascade do |t|
    t.integer "route_id", null: false
    t.integer "stop_id", null: false
    t.integer "sequence_order"
    t.integer "baseline_travel_time_minutes"
    t.integer "dwell_time_minutes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["route_id"], name: "index_route_stops_on_route_id"
    t.index ["stop_id"], name: "index_route_stops_on_stop_id"
  end

  create_table "routes", force: :cascade do |t|
    t.string "name"
    t.string "code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_routes_on_code", unique: true
  end

  create_table "stops", force: :cascade do |t|
    t.string "name"
    t.decimal "latitude"
    t.decimal "longitude"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "trip_events", force: :cascade do |t|
    t.integer "trip_id", null: false
    t.string "event_type"
    t.integer "stop_id", null: false
    t.datetime "observed_time"
    t.integer "delay_delta_minutes"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["stop_id"], name: "index_trip_events_on_stop_id"
    t.index ["trip_id"], name: "index_trip_events_on_trip_id"
  end

  create_table "trips", force: :cascade do |t|
    t.integer "route_id", null: false
    t.integer "vehicle_id", null: false
    t.datetime "scheduled_departure_time"
    t.string "status"
    t.integer "current_delay_minutes"
    t.integer "lock_version"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["route_id"], name: "index_trips_on_route_id"
    t.index ["vehicle_id"], name: "index_trips_on_vehicle_id"
  end

  create_table "vehicles", force: :cascade do |t|
    t.string "code"
    t.string "vehicle_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_vehicles_on_code", unique: true
  end

  add_foreign_key "route_stops", "routes"
  add_foreign_key "route_stops", "stops"
  add_foreign_key "trip_events", "stops"
  add_foreign_key "trip_events", "trips"
  add_foreign_key "trips", "routes"
  add_foreign_key "trips", "vehicles"
end
