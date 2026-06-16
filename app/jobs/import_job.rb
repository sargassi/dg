class ImportJob < ApplicationJob
  queue_as :default

  def perform(session_id)
    data = Rails.cache.read("import:#{session_id}")
    return unless data&.dig(:rows)&.any?

    stats = ImportGeneralService.new.save(data) do |done, total|
      Rails.cache.write("import:progress:#{session_id}", { total: total, done: done, complete: false }, expires_in: 10.minutes)
    end

    Rails.cache.delete("import:#{session_id}")
    Rails.cache.write("import:stats:#{session_id}", stats, expires_in: 5.minutes)
    Rails.cache.write("import:progress:#{session_id}", { total: stats[:total], done: stats[:total], complete: true }, expires_in: 10.minutes)
  end
end