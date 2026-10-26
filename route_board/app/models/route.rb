class Route < ApplicationRecord
  has_many :route_stops, dependent: :destroy
  has_many :stops, through: :route_stops
  has_many :trips, dependent: :destroy
end