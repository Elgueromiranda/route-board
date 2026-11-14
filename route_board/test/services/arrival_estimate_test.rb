# test/services/arrival_estimate_test.rb
require "test_helper"

class ArrivalEstimateTest < ActiveSupport::TestCase
  test "hand-predicted: departs 10:00, 8+3+12 → 10:23; +4 → 10:27" do
    stops = [
      OpenStruct.new(stop_sequence: 1, stop_id: "A", departure_time: "10:00:00"),
      OpenStruct.new(stop_sequence: 2, stop_id: "B", departure_time: "10:08:00"),
      OpenStruct.new(stop_sequence: 3, stop_id: "C", departure_time: "10:23:00")
    ]
    RouteStop.stub(:where, ->(*) { OpenStruct.new(order: stops) }) do
      est = ArrivalEstimate.new("TEST", delay_minutes: 0)
      assert_equal "10:23:00", est.final_arrival[:estimated]

      est = ArrivalEstimate.new("TEST", delay_minutes: 4)
      assert_equal "10:27:00", est.final_arrival[:estimated]
    end
  end
end