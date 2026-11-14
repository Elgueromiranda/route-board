# app/services/arrival_estimate.rb
class ArrivalEstimate
  Result = Struct.new(:stop_sequence, :stop_id, :scheduled, :estimated, :observed, keyword_init: true)

  def self.for(trip_id, delay_minutes: 0)
    new(trip_id, delay_minutes: delay_minutes).call
  end

  def initialize(trip_id, delay_minutes: 0)
    @trip_id = trip_id
    @delay   = delay_minutes.to_i
  end

  def call
    stops = RouteStop.where(trip_id: @trip_id).order(:stop_sequence).to_a
    return [] if stops.empty?

    observed_by_stop = TripEvent.where(gtfs_trip_id: @trip_id, event_type: "arrived")
                                .where.not(stop_id: nil)
                                .order(:sequence)
                                .pluck(:stop_id, :occurred_at)
                                .to_h

    stops.map do |rs|
      scheduled_sec = schedule_seconds(rs.departure_time)
      estimated_sec = scheduled_sec + @delay * 60

      Result.new(
        stop_sequence: rs.stop_sequence,
        stop_id:       rs.stop_id,
        scheduled:     rs.departure_time,
        estimated:     seconds_to_hms(estimated_sec),
        observed:      observed_by_stop[rs.stop_id]&.strftime("%H:%M:%S")
      )
    end
  end

  def final_arrival
    stops = RouteStop.where(trip_id: @trip_id).order(:stop_sequence).to_a
    return nil if stops.empty?

    last = stops.last
    {
      scheduled:     last.departure_time,
      estimated:     seconds_to_hms(schedule_seconds(last.departure_time) + @delay * 60),
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