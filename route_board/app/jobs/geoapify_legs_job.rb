class GeoapifyLegsJob < ApplicationJob
  queue_as :default

  def perform(trip_id)
    GeoapifyRouteEstimator.fetch_and_cache_for(trip_id)
  end
end