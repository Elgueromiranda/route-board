module Api
  module V1
    class TripUpdatesController < ApplicationController
      def show
        stream = TripUpdatesStream.fetch
        return head :service_unavailable unless stream

        render json: { stream_url: "/pollen/streams/#{stream.id}" }
      end
    end
  end
end