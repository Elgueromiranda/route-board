require 'json'

data_file = Rails.root.join('db', 'data.json')
if File.exist?(data_file)
  data = JSON.parse(File.read(data_file))
  
  puts "Seeding database from db/data.json..."
  Route.insert_all(data['routes']) if data['routes'].any?
  Stop.insert_all(data['stops']) if data['stops'].any?
  Calendar.insert_all(data['calendars']) if data['calendars'].any?
  Vehicle.insert_all(data['vehicles']) if data['vehicles'].any?
  RouteStop.insert_all(data['route_stops']) if data['route_stops'].any?
  TripEvent.insert_all(data['trip_events']) if data['trip_events'].any?
  AuditEvent.insert_all(data['audit_events']) if data['audit_events'].any?
  
  puts "Done! Loaded #{RouteStop.count} route_stops."
else
  puts "No db/data.json found. Skipping seed."
end