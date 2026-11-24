require "test_helper"

class Api::V1::DispatcherControllerTest < ActionController::TestCase
  tests Api::V1::DispatcherController
  self.fixture_table_names = []

  setup do
    @route = Route.create!(route_id: "route-dispatch", route_long_name: "Dispatch Route", route_short_name: "D1")
    @stop = Stop.create!(stop_id: "stop-dispatch", stop_name: "Dispatch Stop")
    RouteStop.create!(
      route_id: @route.route_id,
      trip_id: "trip-dispatch",
      stop_id: @stop.stop_id,
      stop_sequence: 1,
      departure_time: "08:00:00"
    )
    session[:dispatcher] = {
      "email" => ENV.fetch("DISPATCHER_ADMIN_EMAIL", "eliasmiranda.la@gmail.com")
    }
  end

  test "records a departure event" do
        post :record_event, params: { trip_id: "trip-dispatch", event_type: "departure" }

    assert_response :success
    assert_equal "departure", TripEvent.last.event_type
  end

  test "assigns a vehicle" do
        post :record_event,
          params: { trip_id: "trip-dispatch", event_type: "vehicle", vehicle_label: "Shuttle 999" }

    assert_response :success
    assert_equal "Shuttle 999", Vehicle.last.label
  end

  test "marks a trip as delayed" do
        post :record_event,
          params: { trip_id: "trip-dispatch", event_type: "delayed", delay_minutes: 5 }

    assert_response :success
    assert_equal "delayed", response.parsed_body.fetch("status")
    assert_equal 5, response.parsed_body.fetch("delay_minutes")
  end

  test "marks a trip as canceled" do
        post :record_event, params: { trip_id: "trip-dispatch", event_type: "canceled" }

    assert_response :success
    assert_equal "canceled", TripEvent.last.event_type
  end

  test "clears a delay and restores the prior trip status" do
    TripEvent.create!(gtfs_trip_id: "trip-dispatch", event_type: "departure", occurred_at: Time.current)
    TripEvent.create!(gtfs_trip_id: "trip-dispatch", event_type: "delayed", delay_minutes: 5, occurred_at: Time.current)

        post :record_event,
          params: { trip_id: "trip-dispatch", event_type: "delayed", delay_minutes: 0 }

    assert_response :success
    assert_equal "in_progress", response.parsed_body.fetch("status")
    assert_equal 0, response.parsed_body.fetch("delay_minutes")
  end

  test "returns structured stop estimates" do
    get :show, params: { trip_id: "trip-dispatch" }

    assert_response :success
    estimate = response.parsed_body.dig("stops", 0, "estimate")
    assert_equal "08:00:00", estimate.fetch("scheduled_time")
    assert_equal "08:00:00", estimate.fetch("estimated_time")
    assert_equal 0, estimate.fetch("delay_minutes")
  end

end