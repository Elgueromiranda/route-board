class RouteStop < ApplicationRecord
  belongs_to :stop,  foreign_key: :stop_id,  primary_key: :stop_id,  optional: true
  belongs_to :route, foreign_key: :route_id, primary_key: :route_id, optional: true

  validates :trip_id, :stop_id, :stop_sequence, presence: true
end