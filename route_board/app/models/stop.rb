class Stop < ApplicationRecord
  has_many :route_stops, dependent: :destroy
  has_many :routes, through: :route_stops
end