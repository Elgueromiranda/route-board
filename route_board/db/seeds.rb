require 'json'

data_path = Rails.root.join('db/data.json')
abort "Missing #{data_path}" unless File.exist?(data_path)

data = JSON.parse(File.read(data_path))

# Order matters: parents before children (routes/stops/calendars before route_stops)
# Use insert_all for speed; tables are assumed empty on a fresh db:seed.
Route.insert_all(data['routes'])         if data['routes'].any?
Stop.insert_all(data['stops'])           if data['stops'].any?
Calendar.insert_all(data['calendars'])   if data['calendars'].any?
Vehicle.insert_all(data['vehicles'])     if data['vehicles'].any?
RouteStop.insert_all(data['route_stops']) if data['route_stops'].any?

puts "Seeded: routes=#{Route.count}, stops=#{Stop.count}, calendars=#{Calendar.count}, vehicles=#{Vehicle.count}, route_stops=#{RouteStop.count}"