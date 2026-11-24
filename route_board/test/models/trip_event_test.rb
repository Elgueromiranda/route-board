require "test_helper"

class TripEventTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "state sums delay minutes across delayed events" do
    event = Struct.new(:event_type, :delay_minutes)
    events = [
      event.new("delayed", 4),
      event.new("delayed", 3)
    ]

    state = TripEvent.state_from(events)

    assert_equal 7, state[:delay_minutes]
    assert_equal "delayed", state[:status]
  end

  test "zero-minute delay clears accumulated delay and restores prior status" do
    event = Struct.new(:event_type, :delay_minutes)
    events = [
      event.new("departure", 0),
      event.new("delayed", 5),
      event.new("delayed", 0)
    ]

    state = TripEvent.state_from(events)

    assert_equal 0, state[:delay_minutes]
    assert_equal "in_progress", state[:status]
  end
end
