module Api
  module V1
    class TripsController < ApplicationController
      def index
        routes = Route.includes(:vehicle, route_stops: :stop).all

        render json: routes.map { |route|
          route_stops = route.route_stops.sort_by(&:stop_sequence)

          # pick one trip per route (the first one encountered)
          trip_id    = route_stops.first&.trip_id
          trip_stops = route_stops.select { |rs| rs.trip_id == trip_id }

          {
            route_id:         route.route_id,
            route_short_name: route.route_short_name,
            route_long_name:  route.route_long_name,
            route_color:      route.route_color.present? ? "##{route.route_color.delete_prefix('#')}" : nil,
            vehicle: route.vehicle && {
              id:     route.vehicle.id,
              label:  route.vehicle.label,
              status: route.vehicle.status
            },
            trip: trip_id && {
              trip_id:    trip_id,
              service_id: trip_stops.first&.service_id,
              stops: trip_stops.map { |rs|
                {
                  stop_sequence:  rs.stop_sequence,
                  departure_time: rs.departure_time,
                  stop: {
                    stop_id:   rs.stop&.stop_id,
                    stop_name: rs.stop&.stop_name,
                    stop_desc: rs.stop&.stop_desc,
                    stop_lat:  rs.stop&.stop_lat,
                    stop_lon:  rs.stop&.stop_lon
                  }
                }
              }
            }
          }
        }, status: :ok
      end
    end
  end
end