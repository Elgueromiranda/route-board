require "pollen"

redis_url = ENV.fetch("REDIS_URL", nil) || Rails.application.credentials.redis_url.presence || "redis://127.0.0.1:6379"

Pollen.common.configure do |config|
  config.redis Redis.new(url: redis_url)
  config.owner_class "Route"
end

Pollen.server.configure do |config|
  config.authenticate do |request, _env|
    stream_id = request.path.match(Pollen::ServerConfiguration::UUID_REGEXP)&.to_s
    Pollen::Stream.find_by(id: stream_id)&.owner if stream_id
  end
end

# 3. Start the server in production automatically, or locally if explicitly told
Pollen.server.start! if Rails.env.production? || ENV["START_POLLEN"] == "true"