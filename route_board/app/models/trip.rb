class Trip < ApplicationRecord
  self.primary_key = :trip_id

  STATUSES = ["Scheduled", "In progress", "Delayed", "Canceled", "Completed"].freeze

  def stops
    stored_stops = JSON.parse(stops_json.presence || "[]")
    return stored_stops if stored_stops.any?

    RouteStop.includes(:stop)
      .where(trip_id: trip_id)
      .order(:stop_sequence)
      .filter_map { |route_stop| route_stop.stop&.stop_name }
  end

  def dispatch_json
    {
      id: trip_id,
      route: route_name,
      destination: destination,
      vehicle: vehicle_label,
      stops: stops,
      nextStopIndex: next_stop_index,
      departed: departed,
      status: status
    }
  end
end