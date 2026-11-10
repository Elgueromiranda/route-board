class Route < ApplicationRecord
  self.primary_key = :route_id

  has_many :route_stops, foreign_key: :route_id, primary_key: :route_id
  has_many :stops, through: :route_stops
  has_one  :vehicle, foreign_key: :route_id, primary_key: :route_id   # ← new
end