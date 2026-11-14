module Api
  module V1
    class TripsController < ApplicationController
      def index
        routes = Route.includes(:vehicle, route_stops: :stop).all

render json: routes.map { |route|
  stops   = route.route_stops.sort_by(&:stop_sequence)
  trip_id = stops.first&.trip_id
  trip_stops = stops.select { |rs| rs.trip_id == trip_id }
  state   = trip_id ? TripEvent.state_for(trip_id) : { status: "scheduled", delay_minutes: 0 }
  estimate = trip_id ? ArrivalEstimate.for(trip_id, delay_minutes: state[:delay_minutes]) : []

  {
    route_id: route.route_id,
    route_short_name: route.route_short_name,
    route_long_name:  route.route_long_name,
    route_color:      route.route_color.present? ? "##{route.route_color.delete_prefix('#')}" : nil,
    vehicle: route.vehicle && { id: route.vehicle.id, label: route.vehicle.label, status: route.vehicle.status },
    bay:     nil,
    delayed: state[:status] == "delayed",
    status:  state[:status],
    trip: {
      trip_id:    trip_id,
      service_id: trip_stops.first&.service_id,
      delay_minutes: state[:delay_minutes],
      stops: trip_stops.map { |rs|
        est = estimate.find { |e| e.stop_sequence == rs.stop_sequence }
        {
          stop_sequence:  rs.stop_sequence,
          departure_time: rs.departure_time,
          estimated_time: est&.estimated,
          observed_time:  est&.observed,
          stop: { stop_id: rs.stop&.stop_id, stop_name: rs.stop&.stop_name, stop_desc: rs.stop&.stop_desc,
                  stop_lat: rs.stop&.stop_lat, stop_lon: rs.stop&.stop_lon }
        }
      }
    }
  }
}

      end
      
    end
  end
end