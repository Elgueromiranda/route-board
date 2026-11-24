require "test_helper"

class GeoapifyRouteEstimatorTest < ActiveSupport::TestCase
  test "returns durations from the Geoapify legs array in order" do
    stops = [
      OpenStruct.new(stop_lat: 40.0, stop_lon: -73.0),
      OpenStruct.new(stop_lat: 40.1, stop_lon: -73.1),
      OpenStruct.new(stop_lat: 40.2, stop_lon: -73.2)
    ]
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@read, true)
    response.instance_variable_set(:@body, {
      features: [{ properties: { legs: [{ time: 120 }, { time: 240 }] } }]
    }.to_json)
    http = Object.new
    http.define_singleton_method(:get) { |_request_uri| response }
    http_start = ->(*_args, **_kwargs, &block) { block.call(http) }

    Rails.application.credentials.stub(:dig, nil) do
      ENV.stub(:[], "test-api-key") do
        Net::HTTP.stub(:start, http_start) do
          assert_equal [120.0, 240.0], GeoapifyRouteEstimator.new(stops).call
        end
      end
    end
  end
end