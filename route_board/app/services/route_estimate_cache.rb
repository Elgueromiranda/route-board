# app/services/route_estimate_cache.rb
require "concurrent"

class RouteEstimateCache
  FRESH_FOR = 1.hour

  @store = Concurrent::Map.new

  class << self
    def fetch(route_id)
      entry = @store[route_id]
      return nil if entry.nil?
      entry.merge(fresh: entry[:fetched_at] > FRESH_FOR.ago)
    end

    def write(route_id, attrs)
      @store[route_id] = attrs.merge(route_id: route_id)
    end

    def clear!
      @store.clear
    end
  end
end