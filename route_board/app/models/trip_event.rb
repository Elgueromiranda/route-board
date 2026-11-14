class TripEvent < ApplicationRecord
  belongs_to :trip, optional: true # not used; kept off intentionally

  validate :valid_transition

  before_create :assign_sequence
  after_create_commit :broadcast

  scope :chronological, -> { order(:sequence) }

  def self.latest_for(trip_id)
    where(gtfs_trip_id: trip_id).order(:sequence).last
  end

  def self.state_for(trip_id)
    latest = latest_for(trip_id)
    {
      status:        latest&.event_type == "canceled" ? "canceled" :
                     latest&.event_type == "arrived"  ? "completed" :
                     latest&.event_type == "delayed"  ? "delayed" :
                     latest&.event_type == "departure" ? "in_progress" : "scheduled",
      delay_minutes: where(gtfs_trip_id: trip_id, event_type: "delayed")
                       .order(:sequence).last&.delay_minutes.to_i,
      next_stop_sequence: where(gtfs_trip_id: trip_id, event_type: "arrived").count,
      departed:      exists?(gtfs_trip_id: trip_id, event_type: "departure"),
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
    Api::V1::ArrivalsStreamController.publish(
      trip_id:  gtfs_trip_id,
      route_id: RouteStop.where(trip_id: gtfs_trip_id).pick(:route_id),
      event:    event_type,
      status:   self.class.state_for(gtfs_trip_id)[:status],
      at:       occurred_at.iso8601
    )
  end
end