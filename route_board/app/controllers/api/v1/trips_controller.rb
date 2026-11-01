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

  route_stops = RouteStop
    .includes(:route, :stop)
    .where(service_id: active_services)
    .where(departure_time: to_gtfs.(now_sec)..to_gtfs.(end_sec))

  render json: route_stops.group_by(&:route_id).map { |route_id, r_stops|
    route = r_stops.first&.route

    # Pick the single trip with the earliest departure time in this window
    trip_entry = r_stops.group_by(&:trip_id).min_by { |_, t_stops| 
      t_stops.map(&:departure_time).min 
    }

    trip_data = if trip_entry
      trip_id, t_stops = trip_entry
      first_stop = t_stops.first
      {
        trip_id:    trip_id,
        service_id: first_stop.service_id,
        stops:      t_stops.sort_by(&:stop_sequence).map { |t|
          secs = t.departure_time.split(':').map(&:to_i).then { |h, m, s| h * 3600 + m * 60 + s }
          {
            stop_sequence:  t.stop_sequence,
            departure_time: t.departure_time[0..4],
            minutes_away:   ((secs - now_sec) / 60.0).round,
            stop:           t.stop # Full nested stop object
          }
        }
      }
    else
      nil
    end

    {
      route_id:           route_id,
      route_short_name:   route&.route_short_name,
      route_long_name:    route&.route_long_name,
      route_color:        route&.route_color.present? ? "##{route.route_color}" : nil,
      trip:               trip_data # Singular key holding one trip with all its stops
    }
  }, status: :ok
end
    end
  end
end