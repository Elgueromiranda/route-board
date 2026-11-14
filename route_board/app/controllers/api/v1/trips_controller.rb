module Api
  module V1
    class TripsController < ApplicationController
      def index
        routes = Route.includes(:vehicle, route_stops: :stop)
                      .order(:route_id)
                      .to_a
        trip_ids = routes.filter_map do |route|
          route.route_stops.min_by(&:stop_sequence)&.trip_id
        end.uniq
        events_by_trip = if trip_ids.empty?
          {}
        else
          TripEvent.where(gtfs_trip_id: trip_ids).order(:sequence).to_a.group_by(&:gtfs_trip_id)
        end

        route_payloads = routes.map { |route|
          stops = route.route_stops.sort_by(&:stop_sequence)
          trip_id = stops.first&.trip_id
          trip_stops = stops.select { |route_stop| route_stop.trip_id == trip_id }
          events = events_by_trip.fetch(trip_id, [])
          state = TripEvent.state_for(trip_id, events: events)
          estimate = if trip_id
            ArrivalEstimate.for(
              trip_id,
              delay_minutes: state[:delay_minutes],
              stops: trip_stops,
              events: events
            )
          else
            []
          end
          estimates_by_sequence = estimate.index_by(&:stop_sequence)

          {
            route_id: route.route_id,
            route_short_name: route.route_short_name,
            route_long_name: route.route_long_name,
            route_color: route.route_color.present? ? "##{route.route_color.delete_prefix('#')}" : nil,
            vehicle: route.vehicle && { id: route.vehicle.id, label: route.vehicle.label, status: route.vehicle.status },
            bay: nil,
            delayed: state[:status] == "delayed",
            status: state[:status],
            trip: {
              trip_id: trip_id,
              service_id: trip_stops.first&.service_id,
              delay_minutes: state[:delay_minutes],
              stops: trip_stops.map { |route_stop|
                est = estimates_by_sequence[route_stop.stop_sequence]
                {
                  stop_sequence: route_stop.stop_sequence,
                  departure_time: route_stop.departure_time,
                  estimated_time: est&.estimated,
                  observed_time: est&.observed,
                  stop: {
                    stop_id: route_stop.stop&.stop_id,
                    stop_name: route_stop.stop&.stop_name,
                    stop_desc: route_stop.stop&.stop_desc,
                    stop_lat: route_stop.stop&.stop_lat,
                    stop_lon: route_stop.stop&.stop_lon
                  }
                }
              }
            }
          }
        }

        render json: route_payloads
      end
    end
  end
end