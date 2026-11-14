# app/services/geoapify_route_estimator.rb
require "net/http"
require "json"

class GeoapifyRouteEstimator
  BASE = "https://api.geoapify.com/v1/routing"
  MODE = "bus"

  def initialize(route)
    @route = route
  end

  def call
    waypoints = waypoint_string
    return nil if waypoints.blank?

    api_key = Rails.application.credentials.dig(:geoapify, :api_key) ||
              ENV["GEOAPIFY_API_KEY"]
    return nil if api_key.blank?

    uri = URI(BASE)
    uri.query = URI.encode_www_form(waypoints: waypoints, mode: MODE, apiKey: api_key)

    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
      http.get(uri.request_uri)
    end

    return nil unless res.is_a?(Net::HTTPSuccess)

    json  = JSON.parse(res.body)
    props = json.dig("features", 0, "properties")
    return nil unless props

    {
      distance_meters:  props["distance"],
      duration_seconds: props["time"],
      fetched_at:       Time.current
    }
  rescue StandardError => e
    Rails.logger.warn("[Geoapify] route #{@route&.route_id}: #{e.class} #{e.message}")
    nil
  end

  private

  def ordered_stops
    @ordered_stops ||= begin
      trip_id = @route.route_stops.where.not(trip_id: nil).pick(:trip_id)
      scope   = trip_id ? @route.route_stops.where(trip_id: trip_id) : @route.route_stops
      scope.order(:stop_sequence).to_a
    end
  end

  def waypoint_string
    ordered_stops
      .filter_map(&:stop)
      .select { |s| s.stop_lat.present? && s.stop_lon.present? }
      .map { |s| "#{s.stop_lat},#{s.stop_lon}" }
      .join("|")
  end
end