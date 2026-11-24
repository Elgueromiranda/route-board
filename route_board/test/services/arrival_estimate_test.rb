# test/services/arrival_estimate_test.rb
require "test_helper"

class ArrivalEstimateTest < ActiveSupport::TestCase
  test "chains Geoapify leg durations from the delayed departure" do
    stops = [
      OpenStruct.new(stop_sequence: 1, stop_id: "A", departure_time: "10:00:00"),
      OpenStruct.new(stop_sequence: 2, stop_id: "B", departure_time: "10:08:00"),
      OpenStruct.new(stop_sequence: 3, stop_id: "C", departure_time: "10:23:00")
    ]
    estimate = ArrivalEstimate.new("TEST", delay_minutes: 2, stops: stops, legs: [180, 240])
    estimates = estimate.call

    assert_equal ["10:02:00", "10:07:00", "10:13:00"], estimates.map(&:estimated)
    assert_equal "10:13:00", estimate.final_arrival[:estimated]
  end
end