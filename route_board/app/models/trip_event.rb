class TripEvent < ApplicationRecord
  belongs_to :trip
  belongs_to :stop
end
