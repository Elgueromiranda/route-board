# app/services/geoapify_route_estimator.rb
require "net/http"
require "json"
require "digest"

class GeoapifyRouteEstimator
  BASE = "https://api.geoapify.com/v1/routing"
  MODE = "bus"

  def initialize(stops)
    @stops = Array(stops)
  end

  def call
    coordinates = self.class.coordinates_for(@stops)
    return nil if coordinates.length < 2 || coordinates.any?(&:blank?)

    api_key = Rails.application.credentials.dig(:geoapify, :api_key) ||
              ENV["GEOAPIFY_API_KEY"]
    return nil if api_key.blank?

    uri = URI(BASE)
    uri.query = URI.encode_www_form(waypoints: coordinates.join("|"), mode: MODE, apiKey: api_key)

    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
      http.get(uri.request_uri)
    end

    return nil unless res.is_a?(Net::HTTPSuccess)

    json  = JSON.parse(res.body)
    legs = json.dig("features", 0, "properties", "legs")
    return nil unless legs.is_a?(Array) && legs.length == coordinates.length - 1

    legs.map { |leg| Float(leg.fetch("time")) }
  rescue StandardError => e
    Rails.logger.warn("[Geoapify] trip leg estimate failed: #{e.class} #{e.message}")
    nil
  end

  def self.coordinates_for(stops)
    Array(stops).map do |item|
      stop = item.respond_to?(:stop) ? item.stop : item
      next unless stop&.stop_lat.present? && stop&.stop_lon.present?

      "#{stop.stop_lat},#{stop.stop_lon}"
    end
  end

  def self.cache_key_for(stops)
    coordinates = coordinates_for(stops)
    return if coordinates.length < 2 || coordinates.any?(&:blank?)

    "geoapify:trip-legs:v1:#{Digest::SHA256.hexdigest(coordinates.join("|"))}"
  end

  def self.cached_legs_for(stops)
    cache_key = cache_key_for(stops)
    return unless cache_key

    Rails.cache.fetch(cache_key, expires_in: 60.minutes) { new(stops).call }
  end
end