 require 'csv'

# puts "Seeding bus routes..."
# Route.delete_all

# routes_path = Rails.root.join('vendor', 'gtfs', 'routes.txt')

# CSV.foreach(routes_path, headers: true) do |row|
#   # Filter strictly for bus routes (route_type 3)
#   if row['route_type'].to_i == 3
#     Route.create!(
#       route_id: row['route_id'],
#       route_short_name: row['route_short_name'],
#       route_long_name: row['route_long_name'],
#       route_color: row['route_color']
#     )
#   end
# end

# puts "Successfully imported #{Route.count} bus routes."

# puts "Seeding trips..."
# Trip.delete_all

# trips_path = Rails.root.join('vendor', 'gtfs', 'trips.txt')

# # Use a Set for blazing fast O(1) lookups
# valid_route_ids = Route.pluck(:route_id).to_set

# trips_to_insert = []

# CSV.foreach(trips_path, headers: true) do |row|
#   route_id = row['route_id']

#   if valid_route_ids.include?(route_id)
#     trips_to_insert << {
#       trip_id: row['trip_id'],
#       route_id: route_id,
#       service_id: row['service_id'],
#     }
#   end
# end

# # Bulk insert in batches inside a single transaction
# ActiveRecord::Base.transaction do
#   trips_to_insert.each_slice(5000) do |batch|
#     Trip.insert_all(batch)
#   end
# end

# puts "Successfully imported #{Trip.count} bus trips."
# puts "Seeding route_stops (from stop_times.txt)..."
# RouteStop.delete_all

# stop_times_path = Rails.root.join('vendor', 'gtfs', 'stop_times.txt')

# # O(1) Set lookup for valid bus trip IDs we already imported
# valid_trip_ids = Trip.pluck(:trip_id).to_set

# route_stops_to_insert = []
# batch_size = 5000

# CSV.foreach(stop_times_path, headers: true) do |row|
#   trip_id = row['trip_id']

#   # Only import stop times belonging to our valid bus trips
#   if valid_trip_ids.include?(trip_id)
#     route_stops_to_insert << {
#       trip_id: trip_id,
#       stop_id: row['stop_id'],
#       departure_time: row['departure_time'],
#       stop_sequence: row['stop_sequence'].to_i,
#     }

#     # Flush in batches to keep memory usage low and speed high
#     if route_stops_to_insert.size >= batch_size
#       ActiveRecord::Base.transaction do
#         RouteStop.insert_all(route_stops_to_insert)
#       end
#       route_stops_to_insert.clear
#     end
#   end
# end

# # Insert any remaining records in the buffer
# unless route_stops_to_insert.empty?
#   ActiveRecord::Base.transaction do
#     RouteStop.insert_all(route_stops_to_insert)
#   end
# end

# puts "Successfully imported #{RouteStop.count} route stops."

# puts "Seeding stops..."
# Stop.delete_all

# stops_path = Rails.root.join('vendor', 'gtfs', 'stops.txt')

# # O(1) Set lookup for only the stops that are actually used by our bus route_stops
# valid_stop_ids = RouteStop.distinct.pluck(:stop_id).to_set

# stops_to_insert = []
# batch_size = 5000

# CSV.foreach(stops_path, headers: true) do |row|
#   stop_id = row['stop_id']

#   # Only import stops that exist in our active bus route_stops
#   if valid_stop_ids.include?(stop_id)
#     stops_to_insert << {
#       stop_id: stop_id,
#       stop_name: row['stop_name'],
#       stop_desc: row['stop_desc'],
#       stop_lat: row['stop_lat'],
#       stop_lon: row['stop_lon'],
#     }

#     # Flush in batches for blazing fast inserts
#     if stops_to_insert.size >= batch_size
#       ActiveRecord::Base.transaction do
#         Stop.insert_all(stops_to_insert)
#       end
#       stops_to_insert.clear
#     end
#   end
# end

# # Insert any remaining buffered records
# unless stops_to_insert.empty?
#   ActiveRecord::Base.transaction do
#     Stop.insert_all(stops_to_insert)
#   end
# end
# db/seeds.rb
require "csv"
require "date"

GTFS_DIR = Rails.root.join("vendor", "gtfs")

def parse_gtfs_date(str)
  Date.strptime(str, "%Y%m%d")
end

# 1. Load calendar.txt -> { service_id => { weekdays:, start:, end: } }
calendar = {}
CSV.foreach(GTFS_DIR.join("calendar.txt"), headers: true) do |row|
  calendar[row["service_id"]] = {
    weekdays: [
      row["monday"], row["tuesday"], row["wednesday"],
      row["thursday"], row["friday"], row["saturday"], row["sunday"]
    ].map(&:to_i),
    start_date: parse_gtfs_date(row["start_date"]),
    end_date:   parse_gtfs_date(row["end_date"])
  }
end

# 2. Load calendar_dates.txt -> { service_id => { date => exception_type } }
exceptions = Hash.new { |h, k| h[k] = {} }
CSV.foreach(GTFS_DIR.join("calendar_dates.txt"), headers: true) do |row|
  exceptions[row["service_id"]][parse_gtfs_date(row["date"])] = row["exception_type"].to_i
end

# 3. Expand each service into concrete dates
service_dates = Hash.new { |h, k| h[k] = Set.new }

calendar.each do |service_id, cal|
  (cal[:start_date]..cal[:end_date]).each do |date|
    # Ruby: 0=Sunday, 1=Monday... so map GTFS monday..sunday to wday index
    gtfs_wday = [1, 2, 3, 4, 5, 6, 0][date.wday]
    service_dates[service_id] << date if cal[:weekdays][gtfs_wday] == 1
  end
end

# Apply exceptions
exceptions.each do |service_id, dates|
  dates.each do |date, type|
    if type == 1
      service_dates[service_id] << date        # add
    elsif type == 2
      service_dates[service_id].delete(date)   # remove
    end
  end
end

# 4. Walk trips.txt and insert one row per (trip, date)
Trip.delete_all  # or use insert_all for speed

batch = []
CSV.foreach(GTFS_DIR.join("trips.txt"), headers: true) do |row|
  service_id = row["service_id"]
  dates = service_dates[service_id]
  next if dates.nil? || dates.empty?

  dates.each do |date|
    batch << {
  trip_id:    row["trip_id"],          # raw GTFS trip_id, no suffix
      route_id:   row["route_id"],
      service_id: service_id,
      date:       date
    }
  end

  if batch.size >= 5_000
    Trip.insert_all(batch)
    batch.clear
  end
end
Trip.insert_all(batch, unique_by: [:trip_id, :date])
puts "Seeded #{Trip.count} trip-days"