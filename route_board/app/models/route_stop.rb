class RouteStop < ApplicationRecord
  belongs_to :trip, foreign_key: :trip_id, primary_key: :trip_id
  belongs_to :stop, foreign_key: :stop_id, primary_key: :stop_id
belongs_to :route, foreign_key: :route_id, primary_key: :route_id # <-- Add this line
  validates :trip_id, :stop_id, :stop_sequence, presence: true
end