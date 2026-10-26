class Api::V1::TripsController < ApplicationController

# Public: search and filter trips
      def index
        trips = Trip.includes(:route, :vehicle)
        trips = trips.where(route_id: params[:route_id]) if params[:route_id].present?
        trips = trips.where(status: params[:status]) if params[:status].present?
        trips = trips.where("scheduled_departure_time >= ?", Time.zone.parse(params[:departure_from])) if params[:departure_from].present?

        render json: trips.as_json(include: [:route, :vehicle])
      end

      # Public: get single trip details and timeline
      def show
        trip = Trip.includes(:route, :vehicle, trip_events: :stop).find(params[:id])
        render json: trip.as_json(include: { route: { include: :stops }, vehicle: {}, trip_events: { include: :stop } })
      end

      # Public: get stop arrivals
      def stop_arrivals
        stop = Stop.find(params[:stop_id])
        # Find active trips passing through this stop
        upcoming_trips = Trip.joins(route: :route_stops)
                             .where(route_stops: { stop_id: stop.id })
                             .where(status: %w[scheduled delayed active])

        arrivals = upcoming_trips.map do |trip|
          {
            trip_id: trip.id,
            route_code: trip.route.code,
            scheduled_departure: trip.scheduled_departure_time,
            estimated_arrival: trip.calculate_eta(stop.id),
            status: trip.status,
            current_delay_minutes: trip.current_delay_minutes
          }
        end

        render json: { stop: stop.name, arrivals: arrivals }
      end

      # Dispatcher: record trip update (synthetic observation, delay, status change)
      def record_update
        trip = Trip.find(params[:id])

        ActiveRecord::Base.transaction do
          # Handle potential stale concurrent updates via optimistic locking
          trip.assign_attributes(trip_update_params)
          
          if params[:delay_delta_minutes].present?
            trip.current_delay_minutes += params[:delay_delta_minutes].to_i
            trip.status = "delayed" if trip.current_delay_minutes > 0
          end

          trip.save!

          # Create audit trail & immutable event log for Game Day replay
          TripEvent.create!(
            trip: trip,
            event_type: params[:event_type] || "delay_updated",
            stop_id: params[:stop_id],
            observed_time: Time.current,
            delay_delta_minutes: params[:delay_delta_minutes].to_i,
            notes: params[:notes]
          )

          AuditEvent.create!(
            actor_role: "dispatcher",
            action: "record_trip_update",
            details: "Updated trip #{trip.id}: status=#{trip.status}, delay=#{trip.current_delay_minutes}m"
          )
        end

        render json: { success: true, trip: trip.reload.as_json(include: :trip_events) }
      rescue ActiveRecord::StaleObjectError
        render json: { error: "Conflict: This trip was modified by another dispatcher. Please refresh." }, status: :conflict
      end

      private

      def trip_update_params
        params.permit(:status)
      end
end
