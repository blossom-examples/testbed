class EventsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "testbed_events"
    transmit({event: "connected", release: ENV.fetch("RELEASE_ID", "local"), replica: Socket.gethostname})
  end
end
