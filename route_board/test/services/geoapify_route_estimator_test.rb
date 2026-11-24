require "test_helper"

class GeoapifyRouteEstimatorTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "returns durations from the Geoapify legs array in order" do
    stop = Struct.new(:stop_lat, :stop_lon)
    stops = [
      stop.new(40.0, -73.0),
      stop.new(40.1, -73.1),
      stop.new(40.2, -73.2)
    ]
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@read, true)
    response.instance_variable_set(:@body, {
      features: [{ properties: { legs: [{ time: 120 }, { time: 240 }] } }]
    }.to_json)
    http = Object.new
    http.define_singleton_method(:get) { |_request_uri| response }
    http_start = ->(*_args, **_kwargs, &block) { block.call(http) }

    with_method_stub(Rails.application.credentials, :dig, ->(*) { nil }) do
      with_method_stub(ENV, :[], ->(key) { key == "GEOAPIFY_API_KEY" ? "test-api-key" : ENV.fetch(key, nil) }) do
        with_method_stub(Net::HTTP, :start, http_start) do
          assert_equal [120.0, 240.0], GeoapifyRouteEstimator.new(stops).call
        end
      end
    end
  end

  test "cache misses enqueue a fetch instead of calling Geoapify inline" do
    stop = Struct.new(:trip_id, :stop_lat, :stop_lon)
    stops = [
      stop.new("trip-cache", 40.0, -73.0),
      stop.new("trip-cache", 40.1, -73.1)
    ]
    enqueued_trip_ids = []

    with_method_stub(Rails.cache, :read, ->(*) { nil }) do
      with_method_stub(Rails.cache, :write, ->(*) { true }) do
        with_method_stub(GeoapifyLegsJob, :perform_later, ->(trip_id) { enqueued_trip_ids << trip_id }) do
          assert_nil GeoapifyRouteEstimator.cached_legs_for(stops)
        end
      end
    end

    assert_equal ["trip-cache"], enqueued_trip_ids
    assert_equal 5.minutes, GeoapifyRouteEstimator::CACHE_TTL
  end

  private

  def with_method_stub(receiver, method_name, replacement)
    original = receiver.method(method_name)
    receiver.define_singleton_method(method_name, replacement)
    yield
  ensure
    receiver.define_singleton_method(method_name, original)
  end
end