class Trip < ApplicationRecord
  belongs_to :route
  belongs_to :vehicle
  has_many :trip_events, dependent: :destroy
end