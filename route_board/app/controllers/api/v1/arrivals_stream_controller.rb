# app/controllers/api/v1/arrivals_stream_controller.rb
class Api::V1::ArrivalsStreamController < ApplicationController
  include ActionController::Live

  def index
    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['X-Accel-Buffering'] = 'no' # Disable Nginx buffering if deployed

    sse = ActionController::Live::SSE.new(response.stream, retry: 3000, event: 'trip_update')

    # Handle Game Day Replay: Check both headers and params for Last-Event-ID
    last_event_id = request.headers['Last-Event-ID'] || params[:last_event_id]
    last_id = last_event_id.to_i

    # Replay any events missed while disconnected
    if last_id > 0
      TripEvent.where("id > ?", last_id).order(:id).find_each do |event|
        sse.write({
          event_id: event.id,
          trip_id: event.trip_id,
          event_type: event.event_type,
          delay_delta_minutes: event.delay_delta_minutes,
          observed_time: event.observed_time,
          notes: event.notes
        }, id: event.id)
      end
    else
      # Send initial connection handshake if no ID provided
      sse.write({ message: "Connected to RouteBoard Live Arrival Stream" }, id: TripEvent.maximum(:id) || 0)
    end

    # Keep connection alive and poll for new events (lightweight zero-dependency pub/sub alternative)
    loop do
      current_max_id = TripEvent.maximum(:id) || 0
      if current_max_id > last_id
        TripEvent.where("id > ?", last_id).order(:id).find_each do |event|
          sse.write({
            event_id: event.id,
            trip_id: event.trip_id,
            event_type: event.event_type,
            delay_delta_minutes: event.delay_delta_minutes,
            observed_time: event.observed_time,
            notes: event.notes
          }, id: event.id)
          last_id = event.id
        end
      end
      sleep 2
    end
  rescue IOError
    # Client disconnected gracefully
  ensure
    sse.close
  end
end