class WorkItem < ApplicationRecord
  validates :request_key, presence: true, length: {maximum: 100}, format: {with: /\A[a-zA-Z0-9_-]+\z/}
  validates :duration_ms, numericality: {only_integer: true, in: 0..1000}

  def self.dispatch_pending
    where(completed_at: nil).where("created_at > ?", 1.day.ago).limit(100).each do |item|
      WorkJob.perform_later(item.id)
    end
  end
end
