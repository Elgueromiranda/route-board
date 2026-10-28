# app/controllers/api/v1/arrivals_stream_controller.rb
class Api::V1::ArrivalsStreamController < ApplicationController
  include ActionController::Live

  def index
    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['X-Accel-Buffering'] = 'no'

    sse = ActionController::Live::SSE.new(response.stream, retry: 3000, event: 'trip_update')

    # Read Last-Event-ID from headers or params (managed automatically by EventSource on reconnect)
    last_event_id = request.headers['Last-Event-ID'] || params[:last_event_id]
    last_id = last_event_id.to_i

    # Replay missed events if client is reconnecting after a drop
    if last_id > 0
      TripEvent.where("id > ?", last_id).order(:id).find_each do |event|
        write_sse(sse, event)
      end
    else
      sse.write({ message: "Connected to RouteBoard Stream" }, id: TripEvent.maximum(:id) || 0)
    end

    # Real-time polling loop for active connection
    loop do
      current_max_id = TripEvent.maximum(:id) || 0
      if current_max_id > last_id
        TripEvent.where("id > ?", last_id).order(:id).find_each do |event|
          write_sse(sse, event)
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

  private

  def write_sse(sse, event)
    sse.write({
      event_id: event.id,
      trip_id: event.trip_id,
      event_type: event.event_type,
      delay_delta_minutes: event.delay_delta_minutes,
      observed_time: event.observed_time,
      notes: event.notes
    }, id: event.id)
  end
end