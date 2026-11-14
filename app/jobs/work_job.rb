class WorkJob < ApplicationJob
  def perform(id)
    item = WorkItem.find(id)
    item.with_lock do
      return if item.completed_at

      sleep(item.duration_ms / 1000.0)
      item.update!(completed_at: Time.current, effect_count: item.effect_count + 1,
        processed_by: "#{ENV.fetch("SERVICE_NAME", "local")}:#{Socket.gethostname}:#{Process.pid}")
    end
    ActionCable.server.broadcast("testbed_events", {event: "job_completed", id: item.id, at: item.completed_at.iso8601})
  end
end
