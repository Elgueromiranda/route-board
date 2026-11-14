class TripUpdatesStream
  ID = "7c42b15e-19a4-4cce-bb1f-6a83028c9114"
  TIMEOUT = 86_400

  def self.fetch
    owner = Route.order(:route_id).first
    return unless owner

    stream = Pollen::Stream.find_or_initialize_by(id: ID)
    stream.owner = owner if stream.owner_id != owner.route_id
    stream.timeout = TIMEOUT
    stream.status = :pending if stream.persisted? && !stream.pending?
    stream.save! if stream.new_record? || stream.changed?
    stream
  end
end