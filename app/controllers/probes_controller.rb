class ProbesController < ApplicationController
  before_action :no_cache

  def live
    render json: identity
  end

  def ready
    raise "Readiness intentionally disabled" if ENV["READY_MODE"] == "fail"
    delay = ENV.fetch("READY_DELAY_SECONDS", "0").to_i.clamp(0, 120)
    raise "Startup delay" if Process.clock_gettime(Process::CLOCK_MONOTONIC) - TESTBED_BOOT_CLOCK < delay
    WorkItem.connection.select_value("SELECT 1")
    SolidQueue::Job.connection.select_value("SELECT 1")
    check_redis
    render json: identity.merge(ready: true)
  rescue => error
    Rails.logger.warn("readiness_failed class=#{error.class}")
    render json: identity.merge(ready: false), status: :service_unavailable
  end

  def status
    jobs, completed, effects, last_id = WorkItem.pick(Arel.sql("COUNT(*), COUNT(completed_at), COALESCE(SUM(effect_count), 0), MAX(CASE WHEN completed_at IS NOT NULL THEN id END)"))
    render json: identity.merge(jobs: jobs, completed: completed, effects: effects, last_completed_id: last_id)
  end

  def private_api
    base = ENV["PRIVATE_API_URL"]
    return render(json: {error: "Private API is not configured"}, status: :service_unavailable) if base.blank?

    uri = URI.join(base, "/api/status")
    response = Net::HTTP.start(uri.host, uri.port, open_timeout: 2, read_timeout: 3) { |http| http.get(uri.request_uri) }
    render json: {web: identity, api: JSON.parse(response.body)}, status: response.code.to_i
  rescue
    render json: {error: "Private API unavailable"}, status: :service_unavailable
  end

  def slow
    sleep(params.fetch(:seconds, "1").to_f.clamp(0, 30))
    render json: identity.merge(complete: true)
  end

  private

  def check_redis
    client = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"), timeout: 2)
    client.ping
  ensure
    client&.close
  end

  def no_cache
    response.headers["Cache-Control"] = "no-store"
  end

  def identity
    {release: ENV.fetch("RELEASE_ID", "local"), service: ENV.fetch("SERVICE_NAME", "web"),
     replica: Socket.gethostname, pid: Process.pid, boot_started_at: Rails.configuration.x.boot_started_at.iso8601,
     observed_at: Time.now.utc.iso8601(3)}
  end
end
