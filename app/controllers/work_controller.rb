class WorkController < ActionController::API
  before_action :authorize_token

  def show
    item = WorkItem.find_by(request_key: params[:request_key])
    return head :not_found unless item

    render json: item.slice(:id, :request_key, :effect_count, :completed_at, :processed_by)
  end

  def create
    key = params[:request_key].to_s
    duration = Integer(params.fetch(:duration_ms, 50))
    return render(json: {error: "duration_ms must be between 0 and 1000"}, status: :unprocessable_entity) unless (0..1000).cover?(duration)

    item = WorkItem.create_or_find_by!(request_key: key) { |record| record.duration_ms = duration }
    return render(json: {error: "request_key already has a different duration"}, status: :conflict) if item.duration_ms != duration

    WorkJob.perform_later(item.id) unless item.completed_at
    render json: {id: item.id, request_key: item.request_key, completed: item.completed_at.present?}, status: :accepted
  rescue ActiveRecord::RecordInvalid, ArgumentError, TypeError
    render json: {error: "Use a request_key of 1–100 letters, numbers, underscores or hyphens and an integer duration_ms"}, status: :unprocessable_entity
  end

  private

  def authorize_token
    expected = ENV["TESTBED_TOKEN"].to_s
    supplied = request.headers["Authorization"].to_s.delete_prefix("Bearer ")
    head :unauthorized unless request.headers["Authorization"].to_s.start_with?("Bearer ") && expected.bytesize >= 32 && ActiveSupport::SecurityUtils.secure_compare(expected, supplied)
  end
end
