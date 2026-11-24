# app/services/geoapify_route_estimator.rb
require "net/http"
require "json"
require "digest"

class GeoapifyRouteEstimator
  BASE = "https://api.geoapify.com/v1/routing"
  MODE = "bus"
  CACHE_TTL = 5.minutes
  FETCH_LOCK_TTL = 30.seconds

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

    "geoapify:trip-legs:v2:#{Digest::SHA256.hexdigest(coordinates.join("|"))}"
  end

  def self.cached_legs_for(stops)
    cache_key = cache_key_for(stops)
    return unless cache_key

    legs = Rails.cache.read(cache_key)
    enqueue_fetch(stops, cache_key) if legs.nil?
    legs
  end

  def self.fetch_and_cache_for(trip_id)
    stops = RouteStop.includes(:stop).where(trip_id: trip_id).order(:stop_sequence).to_a
    cache_key = cache_key_for(stops)
    return unless cache_key

    legs = new(stops).call
    Rails.cache.write(cache_key, legs, expires_in: CACHE_TTL) if legs
    legs
  end

  def self.enqueue_fetch(stops, cache_key)
    trip_id = Array(stops).first&.trip_id
    return if trip_id.blank?

    lock_key = "#{cache_key}:fetching"
    return unless Rails.cache.write(lock_key, true, expires_in: FETCH_LOCK_TTL, unless_exist: true)

    GeoapifyLegsJob.perform_later(trip_id)
  rescue StandardError => e
    Rails.cache.delete(lock_key) if lock_key
    Rails.logger.warn("[Geoapify] unable to enqueue trip #{trip_id}: #{e.class} #{e.message}")
  end
end