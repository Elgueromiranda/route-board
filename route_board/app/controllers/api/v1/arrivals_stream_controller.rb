# app/controllers/api/v1/arrivals_stream_controller.rb
module Api
  module V1
    class ArrivalsStreamController < ApplicationController
      include ActionController::Live

      SUBSCRIBERS = Concurrent::Array.new

      # Called from the dispatcher's write action
      def self.publish(payload)
        json = payload.is_a?(String) ? payload : JSON.generate(payload)
        SUBSCRIBERS.each do |queue|
          queue << json
        rescue StandardError
          next
        end
      end

      def show
        response.headers["Content-Type"]  = "text/event-stream"
        response.headers["Cache-Control"] = "no-cache"
        response.headers["X-Accel-Buffering"] = "no"  # disables nginx buffering 

        queue = Queue.new
        SUBSCRIBERS << queue

        # Tell the client the stream is open
        response.stream.write(": connected\n\n")

        loop do
          begin
            msg = queue.pop(true)  # non-blocking
            response.stream.write("data: #{msg}\n\n")
          rescue ThreadError
            # nothing queued — send a heartbeat and wait
            response.stream.write(": ping\n\n")
            sleep 15
          end
        end
      rescue IOError, ActionController::Live::ClientDisconnected
        # client disconnected — normal
      ensure
        SUBSCRIBERS.delete(queue)
        response.stream.close
      end
    end
  end
end