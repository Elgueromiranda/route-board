class Stop < ApplicationRecord
  self.primary_key = :stop_id

  has_many :route_stops, foreign_key: :stop_id, primary_key: :stop_id, dependent: :destroy
  has_many :trips, through: :route_stops, source: :trip

  validates :stop_id, presence: true, uniqueness: true
end