module Api
  module V1
    class TripsController < ApplicationController
      before_action :require_dispatcher!, only: %i[stops form_options create]

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

          {
            route_id: route.route_id,
            route_short_name: route.route_short_name,
            route_long_name: route.route_long_name,
            route_color: route.route_color.present? ? "##{route.route_color.delete_prefix('#')}" : nil,
            vehicle: route.vehicle && { id: route.vehicle.id, label: route.vehicle.label, status: route.vehicle.status },
            status: state[:status],
            trip: {
              trip_id: trip_id,
              service_id: trip_stops.first&.service_id,
              delay_minutes: state[:delay_minutes],
              stops: trip_stops.map { |route_stop|
                # Parse the string "14:30:37" and format to "2:30 PM"
                parsed_time = route_stop.departure_time.present? ? Time.parse(route_stop.departure_time) : nil
                formatted_time = parsed_time&.strftime("%-I:%M %p")

                {
                  stop_sequence: route_stop.stop_sequence,
                  departure_time: formatted_time,
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

      def estimates
        trip_ids = Array(params[:trip_ids]).map(&:to_s).reject(&:blank?).uniq
        return render json: { error: "trip_ids cannot exceed 20" }, status: :unprocessable_entity if trip_ids.length > 20

        stops_by_trip = RouteStop.includes(:stop)
                                 .where(trip_id: trip_ids)
                                 .order(:trip_id, :stop_sequence)
                                 .to_a
                                 .group_by(&:trip_id)
        events_by_trip = TripEvent.where(gtfs_trip_id: trip_ids)
                .order(:sequence)
                .to_a
                .group_by(&:gtfs_trip_id)

        payload = trip_ids.to_h do |trip_id|
          stops = stops_by_trip.fetch(trip_id, [])
          cacheable = GeoapifyRouteEstimator.cache_key_for(stops).present?
          legs = GeoapifyRouteEstimator.cached_legs_for(stops)
          events = events_by_trip.fetch(trip_id, [])
          state = TripEvent.state_for(trip_id, events: events)
          estimates = ArrivalEstimate.for(
            trip_id,
            delay_minutes: state[:delay_minutes],
            stops: stops,
            events: events,
            legs: legs
          )

          stop_times = estimates.to_h do |estimate|
            [
              estimate.stop_sequence.to_s,
              {
                estimated_time: format_estimated_time(estimate.estimated),
                scheduled_time: format_estimated_time(estimate.scheduled),
                delay_minutes: state[:delay_minutes]
              }
            ]
          end
          available = estimates.any? && estimates.all?(&:available)
          [trip_id, { available: available, pending: cacheable && !available, stops: stop_times }]
        end

        render json: payload
      end

      def stops
        render json: Stop.order(:stop_name, :stop_id).map { |stop|
          { stop_id: stop.stop_id, stop_name: stop.stop_name, stop_desc: stop.stop_desc }
        }
      end

      def form_options
        render json: {
          stops: Stop.order(:stop_name, :stop_id).map { |stop|
            { stop_id: stop.stop_id, stop_name: stop.stop_name, stop_desc: stop.stop_desc }
          },
          vehicles: Vehicle.where(status: "available", route_id: nil).order(:label).map { |vehicle|
            { id: vehicle.id, label: vehicle.label, status: vehicle.status, route_id: vehicle.route_id }
          },
          service_ids: eligible_service_ids_for_today
        }
      end

      def create
        route_long_name = params[:route_long_name].to_s.strip
        route_short_name = params[:route_short_name].to_s.strip
        stop_ids = Array(params[:stop_ids]).map(&:to_s).reject(&:blank?)
        route_color = params[:route_color].present? ? params[:route_color].to_s.delete_prefix("#") : "126B91"
        departure_time = params[:departure_time].presence&.to_s || "08:00:00"
        service_id = params[:service_id].presence&.to_s

        return render json: { error: "Route name and route short name are required." }, status: :unprocessable_entity if route_long_name.blank? || route_short_name.blank?
        return render json: { error: "A route with this long name already exists." }, status: :unprocessable_entity if Route.where("LOWER(route_long_name) = ?", route_long_name.downcase).exists?
        return render json: { error: "A route with this short name already exists." }, status: :unprocessable_entity if Route.where("LOWER(route_short_name) = ?", route_short_name.downcase).exists?
        return render json: { error: "Choose a service running today." }, status: :unprocessable_entity unless service_id && eligible_service_ids_for_today.include?(service_id)
        return render json: { error: "Choose at least one stop without duplicates." }, status: :unprocessable_entity if stop_ids.empty? || stop_ids.uniq.length != stop_ids.length

        existing_stop_ids = Stop.where(stop_id: stop_ids).pluck(:stop_id).map(&:to_s)
        return render json: { error: "One or more selected stops do not exist." }, status: :unprocessable_entity unless existing_stop_ids.sort == stop_ids.sort

        vehicle_selected = params[:vehicle_id].present? || params[:vehicle_label].present?
        return render json: { error: "An available, unassigned vehicle is required." }, status: :unprocessable_entity unless vehicle_selected

        vehicle = params[:vehicle_id].present? ? Vehicle.find_by(id: params[:vehicle_id]) : Vehicle.find_by(label: params[:vehicle_label])
        return render json: { error: "Choose an available, unassigned vehicle." }, status: :unprocessable_entity unless vehicle&.status == "available" && vehicle.route_id.nil?

        route = nil
        trip_id = nil
        ActiveRecord::Base.transaction do
          route = Route.create!(
            route_id: generate_unique_route_id,
            route_short_name: route_short_name,
            route_long_name: route_long_name,
            route_color: route_color
          )

          vehicle = Vehicle.lock.find(vehicle.id)
          raise ActiveRecord::RecordInvalid.new(vehicle) unless vehicle.status == "available" && vehicle.route_id.nil?

          vehicle.update!(route_id: route.route_id)

          trip_id = generate_unique_trip_id(route.route_id)
          stop_ids.each_with_index do |stop_id, index|
            RouteStop.create!(
              trip_id: trip_id,
              stop_id: stop_id,
              departure_time: departure_time,
              stop_sequence: index + 1,
              route_id: route.route_id,
              service_id: service_id
            )
          end
        end

        render json: created_route_payload(route, trip_id), status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def today_day_column(date = Date.current)
        %w[sunday monday tuesday wednesday thursday friday saturday][date.wday]
      end

      def eligible_service_ids_for_today(date = Date.current)
        Calendar.where(today_day_column(date) => true).order(:service_id).pluck(:service_id)
      end

      def generate_unique_route_id
        existing_nums = Route.pluck(:route_id).filter_map do |route_id|
          Integer(route_id, 10)
        rescue ArgumentError, TypeError
          nil
        end
        candidate = existing_nums.max.to_i + 1
        candidate += 1 while Route.exists?(route_id: candidate.to_s)
        candidate.to_s
      end

      def generate_unique_trip_id(route_id)
        loop do
          candidate = "#{route_id}#{SecureRandom.random_number(10**8).to_s.rjust(8, '0')}"
          return candidate unless RouteStop.exists?(trip_id: candidate) || TripEvent.exists?(gtfs_trip_id: candidate) || Trip.exists?(trip_id: candidate)
        end
      end

      def created_route_payload(route, trip_id)
        route_stops = RouteStop.includes(:stop).where(trip_id: trip_id).order(:stop_sequence).to_a
        state = TripEvent.state_for(trip_id)

        {
          route_id: route.route_id,
          route_short_name: route.route_short_name,
          route_long_name: route.route_long_name,
          route_color: route.route_color.present? ? "##{route.route_color.delete_prefix('#')}" : nil,
          vehicle: route.vehicle && { id: route.vehicle.id, label: route.vehicle.label, status: route.vehicle.status },
          status: state[:status],
          trip: {
            trip_id: trip_id,
            service_id: route_stops.first&.service_id,
            delay_minutes: state[:delay_minutes],
            stops: route_stops.map { |route_stop|
              parsed_time = route_stop.departure_time.present? ? Time.parse(route_stop.departure_time) : nil
              {
                stop_sequence: route_stop.stop_sequence,
                departure_time: parsed_time&.strftime("%-I:%M %p"),
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
      end

      def require_dispatcher!
        dispatcher = session[:dispatcher]
        email = dispatcher && (dispatcher["email"] || dispatcher[:email])
        return head :unauthorized unless email
        return head :forbidden unless email.downcase == ENV.fetch("DISPATCHER_ADMIN_EMAIL", "eliasmiranda.la@gmail.com").downcase
      end

      def format_estimated_time(value)
        hours, minutes = value.split(":").first(2).map(&:to_i)
        Time.utc(2000, 1, 1, hours, minutes).strftime("%-I:%M %p")
      end
    end
  end
end