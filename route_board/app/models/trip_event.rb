# app/models/trip_event.rb
class TripEvent < ApplicationRecord
  belongs_to :trip
  belongs_to :stop, optional: true

  validates :event_type, inclusion: { in: %w[departure arrival delay status_change] }
  validates :delay_delta_minutes, presence: true
end