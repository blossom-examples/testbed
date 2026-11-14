class HeartbeatJob < ApplicationJob
  def perform
    # The minute key makes duplicate scheduler dispatch visible without duplicate effects.
    item = WorkItem.create_or_find_by!(request_key: "heartbeat_#{Time.current.utc.strftime("%Y%m%d%H%M")}")
    WorkJob.perform_later(item.id)
    WorkItem.dispatch_pending
  end
end
