class PollenCorsHijack
  def initialize(app)
    @app = app
    @allowed_origins = ENV.fetch("CORS_ORIGINS", "http://localhost:5173")
                       .split(",")
                       .map(&:strip)
                       .reject(&:empty?)
  end

  def call(env)
    origin = env["HTTP_ORIGIN"]
    route = Pollen.server.configuration.route_regexp
    return @app.call(env) unless origin && @allowed_origins.include?(origin) && env["PATH_INFO"].match?(route)
    return @app.call(env) unless env["rack.hijack"]

    hijack = env["rack.hijack"]
    env["rack.hijack"] = -> { CorsSocket.new(hijack.call, origin) }
    @app.call(env)
  end

  private

  class CorsSocket
    def initialize(socket, origin)
      @socket = socket
      @origin = origin
      @headers_written = false
    end

    def puts(value = nil)
      if !@headers_written && value.to_s.start_with?("HTTP/1.1 ")
        value = [
          value,
          "Access-Control-Allow-Origin: #{@origin}",
          "Access-Control-Allow-Credentials: true",
          "Vary: Origin"
        ].join("\n")
        @headers_written = true
      end

      @socket.puts(value)
    end

    def close
      @socket.close
    end
  end
end