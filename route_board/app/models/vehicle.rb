class Vehicle < ApplicationRecord
  belongs_to :route, foreign_key: :route_id, primary_key: :route_id, optional: true

  enum :status, { available: "available", in_service: "in_service", maintenance: "maintenance", retired: "retired" }
end