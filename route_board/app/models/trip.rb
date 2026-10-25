class Trip < ApplicationRecord
  belongs_to :route
  belongs_to :vehicle
end
