class Event < ApplicationRecord
  belongs_to :eventype

  validates :name, :start_time, presence: true
  validate :end_time_after_start_time

  enum :recurrent, { none: "none", daily: "daily", weekly: "weekly", monthly: "monthly", yearly: "yearly" }, default: "none", prefix: true

  private

  def end_time_after_start_time
    return unless start_time && end_time
    errors.add(:end_time, "must be after or equal to start time") if end_time < start_time
  end

  public

  def display_color
    eventype&.color || "#3B82F6"
  end
end
