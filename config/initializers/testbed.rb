Rails.application.config.x.boot_started_at = TESTBED_BOOT_STARTED_AT
Rails.application.config.active_job.queue_adapter = :solid_queue
Rails.application.config.solid_queue.connects_to = {database: {writing: :queue}}
Rails.application.config.active_job.enqueue_after_transaction_commit = true
Rails.application.config.action_cable.mount_path = nil
Rails.application.config.filter_parameters += [:token, :authorization]
Rails.logger.info("testbed_boot service=#{ENV.fetch("SERVICE_NAME", "local")} release=#{ENV.fetch("RELEASE_ID", "local")} pid=#{Process.pid} started_at=#{TESTBED_BOOT_STARTED_AT.iso8601(3)}")
at_exit { Rails.logger.info("testbed_exit pid=#{Process.pid} at=#{Time.now.utc.iso8601(3)}") }
