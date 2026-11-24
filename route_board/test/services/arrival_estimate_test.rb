# test/services/arrival_estimate_test.rb
require "test_helper"

class ArrivalEstimateTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "chains Geoapify leg durations from the delayed departure" do
    stop = Struct.new(:stop_sequence, :stop_id, :departure_time)
    stops = [
      stop.new(1, "A", "10:00:00"),
      stop.new(2, "B", "10:08:00"),
      stop.new(3, "C", "10:23:00")
    ]
    estimate = ArrivalEstimate.new("TEST", delay_minutes: 2, stops: stops, legs: [180, 240])
    estimates = estimate.call

    assert_equal ["10:02:00", "10:05:00", "10:09:00"], estimates.map(&:estimated)
    assert estimates.all?(&:available)
    assert_equal "10:09:00", estimate.final_arrival[:estimated]
  end

  test "falls back to scheduled times when leg durations are unavailable" do
    stop = Struct.new(:stop_sequence, :stop_id, :departure_time)
    stops = [
      stop.new(1, "A", "10:00:00"),
      stop.new(2, "B", "10:08:00")
    ]

    estimates = ArrivalEstimate.new("TEST", delay_minutes: 4, stops: stops, legs: nil).call

    assert_equal ["10:00:00", "10:08:00"], estimates.map(&:estimated)
    assert estimates.none?(&:available)
  end
end