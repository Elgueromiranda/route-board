module Api
  module V1
    class TripsController < ApplicationController

def index
  now     = Time.zone.now
  today   = now.to_date
  dow     = today.strftime('%A').downcase
  now_sec = now.hour * 3600 + now.min * 60
  end_sec = now_sec + 30 * 60 + 59
  to_gtfs = ->(s) { format('%02d:%02d:%02d', s / 3600, (s % 3600) / 60, s % 60) }

  active_services = Rails.cache.fetch("active_services:#{today}", expires_in: 12.hours) do
    Calendar.where("#{dow} = ?", true)
            .where("start_date <= ? AND end_date >= ?", today, today)
            .pluck(:service_id)
  end

  # Eager load the associations so Rails fetches stops and routes efficiently
  route_stops = RouteStop
    .includes(:route, :stop)
    .where(service_id: active_services)
    .where(departure_time: to_gtfs.(now_sec)..to_gtfs.(end_sec))

  render json: route_stops.group_by(&:route_id).map { |route_id, trips|
    route = trips.first.route
    {
      route_id:           route_id,
      route_short_name: route&.route_short_name,
      route_long_name:  route&.route_long_name,
      route_color:      route&.route_color.present? ? "##{route.route_color}" : nil,
      trips: trips.sort_by(&:stop_sequence).map { |t|
        secs = t.departure_time.split(':').map(&:to_i).then { |h, m, s| h * 3600 + m * 60 + s }
        {
          trip_id:        t.trip_id,
          departure_time: t.departure_time[0..4],
          stop_sequence:  t.stop_sequence,
          service_id:     t.service_id,
          minutes_away:   ((secs - now_sec) / 60.0).round,
          stop:           t.stop # <-- This embeds the full Stop object automatically via the association
        }
      }
    }
  }, status: :ok
end
    end
  end
end