require 'csv'
require 'set'
require 'date'

puts "Cleaning existing database records..."
TripEvent.delete_all rescue nil
Trip.delete_all rescue nil
RouteStop.delete_all rescue nil
Route.delete_all rescue nil
Stop.delete_all rescue nil
Vehicle.delete_all rescue nil

gtfs_dir = Rails.root.join("vendor", "gtfs")

# Helper to parse GTFS date strings (YYYYMMDD) into Date objects
def parse_gtfs_date(date_str)
  return nil unless date_str.present? && date_str.length == 8
  Date.strptime(date_str, '%Y%m%d')
rescue
  nil
end

# Helper to parse GTFS time strings (e.g., "08:30:00" or "25:15:00" past midnight)
def parse_gtfs_time(time_str, base_date)
  return base_date.to_time + 8.hours unless time_str.present?
  parts = time_str.split(':').map(&:to_i)
  hours = parts[0] || 0
  minutes = parts[1] || 0
  seconds = parts[2] || 0
  
  days_offset = hours / 24
  effective_hours = hours % 24
  
  (base_date + days_offset.days).to_time + effective_hours.hours + minutes.minutes + seconds.seconds
end

# 1. Parse calendar.txt for service schedules
puts "1. Parsing calendar.txt for service schedules..."
services = {} 

if File.exist?(gtfs_dir.join("calendar.txt"))
  CSV.foreach(gtfs_dir.join("calendar.txt"), headers: true) do |row|
    s_id = row["service_id"]
    services[s_id] = {
      start_date: parse_gtfs_date(row["start_date"]),
      end_date: parse_gtfs_date(row["end_date"]),
      days: [
        row["monday"].to_i == 1,
        row["tuesday"].to_i == 1,
        row["wednesday"].to_i == 1,
        row["thursday"].to_i == 1,
        row["friday"].to_i == 1,
        row["saturday"].to_i == 1,
        row["sunday"].to_i == 1
      ]
    }
  end
end
puts "Loaded #{services.size} service schedule rules."

# 2. Parse calendar_dates.txt for exception dates
puts "2. Parsing calendar_dates.txt for service exceptions..."
calendar_exceptions = Hash.new { |h, k| h[k] = {} } 

if File.exist?(gtfs_dir.join("calendar_dates.txt"))
  CSV.foreach(gtfs_dir.join("calendar_dates.txt"), headers: true) do |row|
    s_id = row["service_id"]
    date = parse_gtfs_date(row["date"])
    exc_type = row["exception_type"].to_i 
    if date
      calendar_exceptions[s_id][date] = exc_type
    end
  end
end

# 3. Identify valid bus route IDs from routes.txt (route_type == 3)
puts "3. Filtering valid bus routes from routes.txt..."
valid_route_ids = Set.new
route_data_cache = {}

CSV.foreach(gtfs_dir.join("routes.txt"), headers: true) do |row|
  next unless row["route_type"].to_i == 3
  r_id = row["route_id"]
  valid_route_ids.add(r_id)
  route_data_cache[r_id] = {
    name: row["route_long_name"].presence || "Route #{row["route_short_name"]}",
    code: "CTA-#{row["route_short_name"]}"
  }
end
puts "Found #{valid_route_ids.size} bus routes."

# 4. Parse trips.txt linking routes to trips and service_ids
puts "4. Processing bus trips from trips.txt..."
valid_trip_ids = Set.new
route_trips = Hash.new { |h, k| h[k] = [] } 

CSV.foreach(gtfs_dir.join("trips.txt"), headers: true) do |row|
  r_id = row["route_id"]
  next unless valid_route_ids.include?(r_id)
  
  t_id = row["trip_id"]
  valid_trip_ids.add(t_id)
  route_trips[r_id] << {
    trip_id: t_id,
    service_id: row["service_id"],
    headsign: row["trip_headsign"]
  }
end
puts "Found #{valid_trip_ids.size} total valid bus trips."

# 5. Parse stop_times.txt for stop sequences and first-stop departure times
puts "5. Parsing stop_times.txt for stop sequences and departure times..."
trip_stop_sequences = Hash.new { |h, k| h[k] = [] }
trip_first_stop_times = {} 
used_stop_ids = Set.new

CSV.foreach(gtfs_dir.join("stop_times.txt"), headers: true) do |row|
  t_id = row["trip_id"]
  next unless valid_trip_ids.include?(t_id)

  s_id = row["stop_id"]
  seq = row["stop_sequence"].to_i
  used_stop_ids.add(s_id)

  trip_stop_sequences[t_id] << {
    stop_id: s_id,
    sequence: seq
  }
end

CSV.foreach(gtfs_dir.join("stop_times.txt"), headers: true) do |row|
  t_id = row["trip_id"]
  next unless valid_trip_ids.include?(t_id)
  if row["stop_sequence"].to_i == 1
    trip_first_stop_times[t_id] = row["departure_time"]
  end
end

trip_stop_sequences.each { |t_id, stops| stops.sort_by! { |s| s[:sequence] } }
puts "Identified #{used_stop_ids.size} unique physical bus stops."

# 6. Import filtered physical stops
puts "6. Importing filtered bus stops from stops.txt..."
stop_mapping = {}
Stop.transaction do
  CSV.foreach(gtfs_dir.join("stops.txt"), headers: true) do |row|
    s_id = row["stop_id"]
    next unless used_stop_ids.include?(s_id)

    stop = Stop.create!(
      name: row["stop_name"],
      latitude: row["stop_lat"].to_f,
      longitude: row["stop_lon"].to_f
    )
    stop_mapping[s_id] = stop
  end
end
puts "Successfully imported #{Stop.count} filtered bus stops!"

# 7. Create Routes and link baseline RouteStops
puts "7. Creating bus routes and linking baseline stop sequences..."
route_records = {}
Route.transaction do
  route_data_cache.each do |gtfs_route_id, data|
    route = Route.create!(
      name: data[:name],
      code: data[:code]
    )
    route_records[gtfs_route_id] = route

    sample_trip_info = route_trips[gtfs_route_id].first
    next unless sample_trip_info

    stops_list = trip_stop_sequences[sample_trip_info[:trip_id]]
    next unless stops_list

    stops_list.each_with_index do |st_data, index|
      stop = stop_mapping[st_data[:stop_id]]
      next unless stop

      RouteStop.create!(
        route: route,
        stop: stop,
        sequence_order: index + 1,
        baseline_travel_time_minutes: 3,
        dwell_time_minutes: 2
      )
    end
  end
end
puts "Successfully imported #{Route.count} routes with baseline stop sequences!"

# 8. Set up default operational vehicle
puts "8. Setting up default operational vehicle..."
vehicle = Vehicle.find_or_create_by!(code: "CTA-SHUTTLE-01") do |v|
  v.vehicle_type = "Electric Transit Bus"
end

# 9. Blazing-fast batched import of scheduled bus trips across calendar dates
puts "9. Expanding and batch-importing scheduled bus trips across calendar dates..."
imported_trips_count = 0
batch = []
batch_size = 5000
now = Time.current

route_trips.each do |gtfs_route_id, trips|
  route = route_records[gtfs_route_id]
  next unless route

  trips.each do |t_info|
    s_id = t_info[:service_id]
    service_rule = services[s_id]
    next unless service_rule && service_rule[:start_date] && service_rule[:end_date]

    raw_time = trip_first_stop_times[t_info[:trip_id]]
    current_date = service_rule[:start_date]
    end_date = service_rule[:end_date]
    exceptions = calendar_exceptions[s_id]

    while current_date <= end_date
      ruby_wday = current_date.wday
      gtfs_wday_idx = ruby_wday == 0 ? 6 : ruby_wday - 1

      is_scheduled_day = service_rule[:days][gtfs_wday_idx]
      exception_type = exceptions[current_date]

      runs_today = case exception_type
      when 1 then true
      when 2 then false
      else is_scheduled_day
      end

      if runs_today
        departure_time = parse_gtfs_time(raw_time, current_date)

        batch << {
          route_id: route.id,
          vehicle_id: vehicle.id,
          scheduled_departure_time: departure_time,
          status: "scheduled",
          current_delay_minutes: 0,
          created_at: now,
          updated_at: now
        }
        imported_trips_count += 1

        if batch.size >= batch_size
          Trip.insert_all(batch)
          batch.clear
        end
      end

      current_date += 1.day
    end
  end
end

# Insert any remainder
Trip.insert_all(batch) if batch.any?

puts "Successfully imported #{imported_trips_count} scheduled trip instances across the true calendar range!"
puts "Database seeding fully completed!"