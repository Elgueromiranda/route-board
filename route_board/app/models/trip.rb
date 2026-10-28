# app/models/trip.rb
class Trip < ApplicationRecord
  belongs_to :route
  belongs_to :vehicle, optional: true
  has_many :trip_events, dependent: :destroy
  has_many :audit_events, dependent: :destroy

  validates :status, inclusion: { in: %w[scheduled active delayed canceled completed] }
  validates :lock_version, presence: true

  # Deterministic ETA: Scheduled Departure + Baseline Travel/Dwell + Cumulative Delays
  def current_eta(stop)
    return nil if status == 'canceled'

    base_departure = scheduled_departure_time
    accumulated_delay = current_delay_minutes.minutes
    
    # Calculate route segment travel time + dwell time up to the requested stop
    leg_duration = route.travel_duration_to(stop)
    
    base_departure + leg_duration + accumulated_delay
  end

  def current_delay_minutes
    trip_events.sum(:delay_delta_minutes)
  end
end