# app/controllers/api/v1/trips_controller.rb
class Api::V1::TripsController < ApplicationController
  rescue_from ActiveRecord::StaleObjectError, with: :handle_stale_object

 


 def index
    # Force target date to match your seed date (2026-09-11)
    target_date = params[:date] ? Date.parse(params[:date]) : Date.new(2026, 9, 11)
    
    # Correct date range order: beginning of day -> end of day
    start_window = target_date.beginning_of_day
    end_window = target_date.end_of_day

    trips = Trip.includes(:route, :vehicle)
                .where(scheduled_departure_time: start_window..end_window)
                .order(:scheduled_departure_time)
                .limit(15)

    delay_sums = TripEvent.where(trip_id: trips.map(&:id))
                          .group(:trip_id)
                          .sum(:delay_delta_minutes)

    render json: trips.as_json(include: [:route, :vehicle]).map { |trip|
      trip.merge('current_delay_minutes' => delay_sums[trip['id']] || 0)
    }
  end
  # Dispatcher action to record updates / delays
  def record_update
    @trip = Trip.find(params[:id])

    ActiveRecord::Base.transaction do
      # 1. Create audit / trip event log
      event = @trip.trip_events.create!(
        event_type: params[:event_type], # e.g., 'delay'
        delay_delta_minutes: params[:delay_minutes] || 0,
        stop_id: params[:stop_id],
        notes: params[:notes],
        observed_time: Time.current
      )

      # 2. Update trip status/state if provided
      if params[:status].present?
        @trip.status = params[:status]
      end

      # 3. Save triggers optimistic locking check (lock_version)
      @trip.save!

      render json: { success: true, trip: @trip, event: event }, status: :ok
    end
  end

  def stop_arrivals
    stop = Stop.find(params[:stop_id])
    arrivals = stop.trips.map do |trip|
      {
        trip_id: trip.id,
        route_name: trip.route.name,
        scheduled_departure: trip.scheduled_departure_time,
        estimated_arrival: trip.current_eta(stop),
        status: trip.status,
        delay_minutes: trip.current_delay_minutes
      }
    end
    render json: arrivals
  end

  private

  def handle_stale_object
    render json: { 
      error: "Conflict: This trip was modified by another request. Please refresh and retry." 
    }, status: :conflict
  end
end