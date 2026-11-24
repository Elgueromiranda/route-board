module Api
  module V1
    class DispatcherController < ApplicationController
      skip_before_action :verify_authenticity_token, raise: false
      before_action :require_dispatcher!, except: [:me]

      # GET /api/v1/dispatch/me
      def me
        dispatcher = session[:dispatcher]
        return head :unauthorized unless dispatcher
        return head :forbidden unless authorized_email?(dispatcher["email"] || dispatcher[:email])
        render json: dispatcher
      end

      # GET /api/v1/dispatch/trips/:trip_id
      def show
        trip_id = params[:trip_id]
        return render json: { error: "unknown trip" }, status: :not_found unless RouteStop.exists?(trip_id: trip_id)

        render json: trip_json(trip_id)
      end

      # POST /api/v1/dispatch/trips/:trip_id/events
      # { event_type: "departure" | "arrived" | "delayed" | "canceled" | "vehicle",
      #   stop_id?, delay_minutes?, vehicle_id? }
      def record_event
        trip_id = params[:trip_id]
        return render json: { error: "unknown trip" }, status: :not_found unless RouteStop.exists?(trip_id: trip_id)

        event_type = params.require(:event_type)
        dispatcher = session[:dispatcher]
        actor      = dispatcher["email"] || dispatcher[:email]

        unless %w[departure arrived delayed canceled vehicle].include?(event_type)
          return render json: { error: "invalid event_type" }, status: :unprocessable_entity
        end

        event = nil
        ActiveRecord::Base.transaction do
          if event_type == "vehicle"
            route_id = RouteStop.where(trip_id: trip_id).pick(:route_id)
            vehicle = Vehicle.find_or_initialize_by(route_id: route_id)
            vehicle.label = params.require(:vehicle_label)
            vehicle.save!
          end

          event = TripEvent.create!(
            gtfs_trip_id:  trip_id,
            event_type:    event_type,
            stop_id:       params[:stop_id],
            occurred_at:   Time.current,
            delay_minutes: params[:delay_minutes].to_i,
            payload:       params.permit(:stop_id, :delay_minutes, :status, :vehicle_id, :vehicle_label).to_h,
            actor:         actor
          )

          AuditEvent.create!(
            actor:        actor,
            action:       "trip.#{event_type}",
            subject_type: "Trip",
            subject_id:   trip_id,
            payload:      event.payload
          )
        end

        render json: trip_json(trip_id)
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def trip_json(trip_id)
        state    = TripEvent.state_for(trip_id)
        stops    = RouteStop.where(trip_id: trip_id).order(:stop_sequence).includes(:stop)
        legs     = GeoapifyRouteEstimator.cached_legs_for(stops)
        estimate = ArrivalEstimate.for(
          trip_id,
          delay_minutes: state[:delay_minutes],
          stops: stops,
          legs: legs
        )
        estimates_by_sequence = estimate.index_by(&:stop_sequence)
        route    = Route.find_by(route_id: stops.first&.route_id)
        vehicle  = Vehicle.find_by(route_id: route&.route_id)

        {
          trip_id:    trip_id,
          route:      route && {
            route_id:    route.route_id,
            short_name:  route.route_short_name,
            long_name:   route.route_long_name,
            color:       route.route_color
          },
          vehicle:    vehicle && { id: vehicle.id, label: vehicle.label, status: vehicle.status },
          status:     state[:status],
          delay_minutes: state[:delay_minutes],
          next_stop_sequence: state[:next_stop_sequence],
          stops: stops.map { |rs|
            stop = rs.stop
            est = estimates_by_sequence[rs.stop_sequence]
            {
              stop_sequence:  rs.stop_sequence,
              scheduled:      rs.departure_time,
              estimate: est && {
                scheduled_time: rs.departure_time,
                estimated_time: est.estimated,
                delay_minutes: state[:delay_minutes]
              },
              observed:       est&.observed,
              stop: stop && {
                stop_id:   stop.stop_id,
                stop_name: stop.stop_name,
                stop_desc: stop.stop_desc
              }
            }
          },
          events: TripEvent.where(gtfs_trip_id: trip_id).order(:sequence).limit(50).map { |e|
            { sequence: e.sequence, event_type: e.event_type, occurred_at: e.occurred_at, actor: e.actor }
          }
        }
      end

      def require_dispatcher!
        dispatcher = session[:dispatcher]
        return head :unauthorized unless dispatcher
        return head :forbidden unless authorized_email?(dispatcher["email"] || dispatcher[:email])
      end

      def authorized_email?(email)
        email&.downcase == ENV.fetch("DISPATCHER_ADMIN_EMAIL", "eliasmiranda.la@gmail.com").downcase
      end
    end
  end
end