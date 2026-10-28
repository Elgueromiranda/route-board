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
    upcoming_trips = Trip.joins(route: :route_stops)
                         .where(route_stops: { stop_id: stop.id })
                         .where(status: %w[scheduled delayed active])

    arrivals = upcoming_trips.map do |trip|
      {
        trip_id: trip.id,
        route_code: trip.route.code,
        scheduled_departure: trip.scheduled_departure_time,
        estimated_arrival: trip.respond_to?(:calculate_eta) ? trip.calculate_eta(stop.id) : trip.scheduled_departure_time,
        status: trip.status,
        current_delay_minutes: trip.current_delay_minutes
      }
    end

    render json: { stop: stop.name, arrivals: arrivals }
  end

  # Dispatcher: record trip update (synthetic observation, delay, status change)
  def record_update
    trip = Trip.find(params[:id])
    p = trip_update_params

    delay_delta = p[:delay_delta_minutes].present? ? p[:delay_delta_minutes].to_i : (p[:delay_minutes].to_i rescue 0)

    ActiveRecord::Base.transaction do
      if delay_delta != 0
        trip.current_delay_minutes = (trip.current_delay_minutes || 0) + delay_delta
        trip.status = "delayed" if trip.current_delay_minutes > 0
      end

      trip.status = p[:status] if p[:status].present?
      trip.save!

      # Create audit trail & immutable event log for Game Day replay
      TripEvent.create!(
        trip: trip,
        event_type: p[:event_type] || "delay_updated",
        stop_id: p[:stop_id],
        observed_time: Time.current,
        delay_delta_minutes: delay_delta,
        notes: p[:notes]
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
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def trip_update_params
    # Safely accepts either flat JSON or nested under :trip
    source = params[:trip].present? ? params.require(:trip) : params
    source.permit(:status, :current_delay_minutes, :event_type, :stop_id, :notes, :delay_delta_minutes, :delay_minutes)
  end
end