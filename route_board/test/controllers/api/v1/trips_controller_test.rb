require "test_helper"

class Api::V1::TripsControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "index batches route stops and events while retaining arrival state" do
    create_route_with_stops("route-a", "trip-a", ["stop-a", "stop-b"])
    create_route_with_stops("route-b", "trip-b", ["stop-c"])
    TripEvent.create!(gtfs_trip_id: "trip-a", event_type: "delayed", delay_minutes: 7, occurred_at: Time.current)
    TripEvent.create!(gtfs_trip_id: "trip-a", event_type: "arrived", stop_id: "stop-a", occurred_at: Time.zone.parse("2026-11-14 10:08:00"))

    queries = []
    subscriber = lambda do |_name, _start, _finish, _id, payload|
      sql = payload[:sql]
      queries << sql if payload[:name] != "SCHEMA" && sql.match?(/\ASELECT/i)
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      get "/api/v1/trips"
    end

    assert_response :success
    body = response.parsed_body
    route_a = body.find { |route| route["route_id"] == "route-a" }
    assert_equal "completed", route_a["status"]
    assert_equal 7, route_a.dig("trip", "delay_minutes")
    assert_equal "10:07:00", route_a.dig("trip", "stops", 0, "estimated_time")
    assert_equal "10:08:00", route_a.dig("trip", "stops", 0, "observed_time")
    assert_equal 1, queries.count { |sql| sql.include?("\"trip_events\"") }
    assert_equal 1, queries.count { |sql| sql.include?("\"route_stops\"") }
    assert_equal 1, queries.count { |sql| sql.include?("\"stops\"") }
  end

  test "index returns all routes in one response" do
    51.times do |index|
      route_id = "route-%03d" % index
      Route.create!(route_id: route_id, route_short_name: route_id, route_long_name: route_id)
    end

    get "/api/v1/trips"
    assert_response :success
    assert_equal 51, response.parsed_body.length
  end

  test "index returns the assigned vehicle label for a route" do
    create_route_with_stops("route-vehicle", "trip-vehicle", ["stop-vehicle"])
    Vehicle.create!(route_id: "route-vehicle", label: "Shuttle 204")

    get "/api/v1/trips"

    assert_response :success
    route = response.parsed_body.find { |item| item["route_id"] == "route-vehicle" }
    assert_equal "Shuttle 204", route.dig("vehicle", "label")
  end

  test "trip updates endpoint returns a Pollen stream ID with an intercepted route" do
    create_route_with_stops("route-stream", "trip-stream", ["stop-stream"])

    get "/api/v1/trips/updates"

    assert_response :success
    stream_id = response.parsed_body.fetch("stream_id")
    assert_match Pollen::ServerConfiguration::UUID_REGEXP, stream_id
    assert_match Pollen.server.configuration.route_regexp, "/pollens/streams/#{stream_id}"
    assert_equal "route-stream", Pollen::Stream.find(stream_id).owner_id
  end

  private

  def create_route_with_stops(route_id, trip_id, stop_ids)
    Route.create!(route_id: route_id, route_short_name: route_id, route_long_name: route_id)
    stop_ids.each_with_index do |stop_id, index|
      Stop.create!(stop_id: stop_id, stop_name: stop_id)
      RouteStop.create!(
        route_id: route_id,
        trip_id: trip_id,
        stop_id: stop_id,
        departure_time: "10:#{format('%02d', index * 10)}:00",
        stop_sequence: index + 1
      )
    end
  end
end
