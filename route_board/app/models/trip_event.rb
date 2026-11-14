class TripEvent < ApplicationRecord
  belongs_to :trip, optional: true # not used; kept off intentionally

  validate :valid_transition

  before_create :assign_sequence
  after_create_commit :broadcast

  scope :chronological, -> { order(:sequence) }

  def self.latest_for(trip_id)
    where(gtfs_trip_id: trip_id).order(:sequence).last
  end

  def self.state_for(trip_id, events: nil)
    events ||= where(gtfs_trip_id: trip_id).order(:sequence).to_a
    state_from(events)
  end

  def self.state_from(events)
    latest = events.last
    {
      status:        latest&.event_type == "canceled" ? "canceled" :
                     latest&.event_type == "arrived"  ? "completed" :
                     latest&.event_type == "delayed"  ? "delayed" :
                     latest&.event_type == "departure" ? "in_progress" : "scheduled",
      delay_minutes: events.select { |event| event.event_type == "delayed" }.last&.delay_minutes.to_i,
      next_stop_sequence: events.count { |event| event.event_type == "arrived" },
      departed:      events.any? { |event| event.event_type == "departure" },
      last_event:    latest
    }
  end

  private

  def assign_sequence
    self.sequence ||= (TripEvent.maximum(:sequence) || 0) + 1
  end

  def valid_transition
    return unless %w[departure arrived delayed canceled vehicle].include?(event_type)

    latest = self.class.latest_for(gtfs_trip_id)
    return if latest.nil?

    # canceled / completed are terminal
    if %w[canceled arrived].include?(latest.event_type) && %w[departure delayed vehicle].include?(event_type)
      errors.add(:base, "trip already #{latest.event_type}; cannot #{event_type}")
    end
  end

  def broadcast
    return unless Pollen.server.started?

    stream = TripUpdatesStream.fetch
    return unless stream

    payload = {
      trip_id:  gtfs_trip_id,
      route_id: RouteStop.where(trip_id: gtfs_trip_id).pick(:route_id),
      event:    event_type,
      status:   self.class.state_for(gtfs_trip_id)[:status],
      at:       occurred_at.iso8601
    }.to_json

    Pollen.controller.push!(stream, :update, payload)
  rescue StandardError => error
    Rails.logger.warn("[Pollen] trip event broadcast failed: #{error.class} #{error.message}")
  end
end