require "test_helper"

class WorkTest < ActionDispatch::IntegrationTest
  setup do
    @old_token = ENV["TESTBED_TOKEN"]
    ENV["TESTBED_TOKEN"] = "disposable-fixture-token-0123456789abcdef"
    ActiveJob::Base.queue_adapter = :test
  end

  teardown { ENV["TESTBED_TOKEN"] = @old_token }

  test "writes fail closed without configured credentials and with invalid authorization" do
    [nil, "short"].each do |configured|
      ENV["TESTBED_TOKEN"] = configured
      assert_no_difference("WorkItem.count") { post "/api/jobs", params: {request_key: "unauthorized"}, as: :json }
      assert_response :unauthorized
    end
  end

  test "retrying the same request and worker execution produce exactly one effect" do
    headers = {"Authorization" => "Bearer #{ENV.fetch("TESTBED_TOKEN")}"}
    2.times do
      post "/api/jobs", params: {request_key: "same_request", duration_ms: 0}, headers: headers, as: :json
      assert_response :accepted
    end
    assert_equal 1, WorkItem.where(request_key: "same_request").count
    item = WorkItem.find_by!(request_key: "same_request")
    2.times { WorkJob.perform_now(item.id) }
    assert_equal 1, item.reload.effect_count
    get "/qa"
    assert_response :success
    assert_equal 1, response.parsed_body["jobs"]
    assert_equal 1, response.parsed_body["completed"]
    assert_equal 1, response.parsed_body["effects"]
    post "/api/jobs", params: {request_key: "same_request", duration_ms: 1}, headers: headers, as: :json
    assert_response :conflict
  end

  test "rejects unbounded and malformed input" do
    headers = {"Authorization" => "Bearer #{ENV.fetch("TESTBED_TOKEN")}"}
    [{request_key: "bad key"}, {request_key: "valid", duration_ms: 1001}, {request_key: "valid", duration_ms: "oops"}].each do |input|
      assert_no_difference("WorkItem.count") { post "/api/jobs", params: input, headers: headers, as: :json }
      assert_response :unprocessable_entity
    end
  end

  test "liveness remains available when readiness deliberately fails" do
    old_mode = ENV["READY_MODE"]
    ENV["READY_MODE"] = "fail"
    get "/ready"
    assert_response :service_unavailable
    assert_equal false, response.parsed_body["ready"]
    get "/up"
    assert_response :success
    assert response.parsed_body.key?("release")
  ensure
    ENV["READY_MODE"] = old_mode
  end

  test "readiness checks primary queue and Redis dependencies" do
    old_redis = ENV["REDIS_URL"]
    get "/ready"
    assert_response :success
    ENV["REDIS_URL"] = "redis://127.0.0.1:1/0"
    get "/ready"
    assert_response :service_unavailable
  ensure
    ENV["REDIS_URL"] = old_redis
  end
end
