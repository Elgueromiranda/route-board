# app/services/arrival_estimate.rb
class ArrivalEstimate
  Result = Struct.new(:stop_sequence, :stop_id, :scheduled, :estimated, :observed, keyword_init: true)

  def self.for(trip_id, delay_minutes: 0, stops: nil, events: nil, legs: nil)
    new(trip_id, delay_minutes: delay_minutes, stops: stops, events: events, legs: legs).call
  end

  def initialize(trip_id, delay_minutes: 0, stops: nil, events: nil, legs: nil)
    @trip_id = trip_id
    @delay   = delay_minutes.to_i
    @stops = stops
    @events = events
    @legs = Array(legs)
  end

  def call
    stops = (@stops || RouteStop.where(trip_id: @trip_id).order(:stop_sequence).to_a)
      .sort_by(&:stop_sequence)
    return [] if stops.empty?
    return [] if stops.length > 1 && @legs.length < stops.length - 1

    events = @events || TripEvent.where(gtfs_trip_id: @trip_id, event_type: "arrived")
                                 .where.not(stop_id: nil)
                                 .order(:sequence)
                                 .to_a
    observed_by_stop = events.select { |event| event.event_type == "arrived" && event.stop_id }
                             .to_h { |event| [event.stop_id, event.occurred_at] }

    estimated_seconds = schedule_seconds(stops.first.departure_time) + @delay * 60
    stops.each_with_index.map do |rs, index|
      if index.positive?
        estimated_seconds += Float(@legs[index - 1]) + @delay * 60
      end

      Result.new(
        stop_sequence: rs.stop_sequence,
        stop_id:       rs.stop_id,
        scheduled:     rs.departure_time,
        estimated:     seconds_to_hms(estimated_seconds),
        observed:      observed_by_stop[rs.stop_id]&.strftime("%H:%M:%S")
      )
    end
  end

  def final_arrival
    last = call.last
    return nil unless last

    {
      scheduled:     last.scheduled,
      estimated:     last.estimated,
      delay_minutes: @delay
    }
  end

  private

  def schedule_seconds(value)
    return 0 if value.blank?
    h, m, s = value.split(":").map(&:to_i)
    h * 3600 + m * 60 + s
  end

  def seconds_to_hms(total)
    total = ((total % 86_400) + 86_400) % 86_400
    format("%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
  end
end