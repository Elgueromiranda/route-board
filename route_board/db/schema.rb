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

ActiveRecord::Schema[8.1].define(version: 2026_11_10_180743) do
  create_table "calendars", primary_key: "service_id", id: :string, force: :cascade do |t|
    t.boolean "monday", default: false
    t.boolean "tuesday", default: false
    t.boolean "wednesday", default: false
    t.boolean "thursday", default: false
    t.boolean "friday", default: false
    t.boolean "saturday", default: false
    t.boolean "sunday", default: false
    t.date "start_date"
    t.date "end_date"
  end

  create_table "route_stops", id: false, force: :cascade do |t|
    t.string "trip_id", null: false
    t.string "stop_id", null: false
    t.string "departure_time"
    t.integer "stop_sequence"
    t.string "route_id"
    t.string "service_id"
    t.index ["route_id"], name: "index_route_stops_on_route_id"
    t.index ["service_id"], name: "index_route_stops_on_service_id"
    t.index ["stop_id"], name: "index_route_stops_on_stop_id"
    t.index ["trip_id"], name: "index_route_stops_on_trip_id"
  end

  create_table "routes", primary_key: "route_id", id: :string, force: :cascade do |t|
    t.string "route_short_name"
    t.string "route_long_name"
    t.string "route_color"
  end

  create_table "stops", primary_key: "stop_id", id: :string, force: :cascade do |t|
    t.string "stop_name"
    t.string "stop_desc"
    t.string "stop_lat"
    t.string "stop_lon"
  end

  create_table "trips", id: false, force: :cascade do |t|
    t.string "route_id"
    t.string "service_id"
    t.string "trip_id"
  end

  create_table "vehicles", force: :cascade do |t|
    t.string "label"
    t.string "status", default: "available", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "route_id"
    t.index ["route_id"], name: "index_vehicles_on_route_id", unique: true
    t.index ["status"], name: "index_vehicles_on_status"
  end
end
