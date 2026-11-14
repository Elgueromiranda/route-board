module Api
  module V1
    class RouteEstimatesController < ApplicationController
      def show
        route = Route.find_by(route_id: params[:route_id])
        unless route
          return render json: { route_id: params[:route_id], available: false }, status: :not_found
        end

        cached = RouteEstimateCache.fetch(route.route_id)

        # 1) fresh cache
        if cached && cached[:fresh]
          return render json: payload(cached, cached: true, stale: false)
        end

        # 2) live fetch
        result = GeoapifyRouteEstimator.new(route).call
        if result
          RouteEstimateCache.write(route.route_id, result)
          return render json: payload(result, cached: false, stale: false)
        end

        # 3) stale cache
        if cached
          return render json: payload(cached, cached: true, stale: true)
        end

        # 4) no cache, provider down
        render json: { route_id: route.route_id, available: false }
      end

      private

      def payload(est, cached:, stale:)
        {
          route_id:         est[:route_id] || params[:route_id],
          available:        true,
          distance_meters:  est[:distance_meters],
          duration_seconds: est[:duration_seconds],
          fetched_at:       est[:fetched_at]&.iso8601,
          cached:           cached,
          stale:            stale
        }
      end
    end
  end
end