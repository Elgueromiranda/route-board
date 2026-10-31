module Api
  module V1
    class DispatcherController < ApplicationController
      skip_before_action :verify_authenticity_token, raise: false

      # POST /api/v1/dispatcher/trips
      # Create a new trip (matches your exact trips table structure)
      def create_trip
        trip = Trip.new(trip_params)
        
        if trip.save
          render json: { success: true, trip: trip }, status: :created
        else
          render json: { success: false, errors: trip.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/dispatcher/trips/:trip_id/stops
      # Add or record stop sequence/departure times for a trip in route_stops
      def add_stop
        trip = Trip.find_by!(trip_id: params[:trip_id])
        route_stop = trip.route_stops.build(route_stop_params)

        if route_stop.save
          render json: { success: true, route_stop: route_stop }, status: :created
        else
          render json: { success: false, errors: route_stop.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def trip_params
        params.require(:trip).permit(:trip_id, :route_id, :service_id)
      end

      def route_stop_params
        params.require(:route_stop).permit(:stop_id, :departure_time, :stop_sequence)
      end
    end
  end
end