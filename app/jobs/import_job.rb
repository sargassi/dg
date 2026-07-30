class ImportJob < ApplicationJob
  queue_as :default

  def perform(session_id)
    data = Rails.cache.read("import:#{session_id}")
    return unless data&.dig(:rows)&.any?

    log_id = Rails.cache.read("import:log:#{session_id}")
    import_log = ImportLog.find_by(id: log_id)

    stats = ImportPersister.new.save(data) do |done, total|
      Rails.cache.write("import:progress:#{session_id}", { total: total, done: done, complete: false, import_log_id: log_id }, expires_in: 10.minutes)
    end

    Rails.cache.delete("import:#{session_id}")
    Rails.cache.write("import:stats:#{session_id}", stats, expires_in: 5.minutes)
    Rails.cache.write("import:progress:#{session_id}", { total: stats[:total], done: stats[:total], complete: true, import_log_id: log_id }, expires_in: 10.minutes)

    if import_log
      import_log.update!(
        status: 'completed',
        total_rows: stats[:total],
        created_count: stats[:created],
        updated_count: stats[:updated],
        error_count: stats[:errors].size,
        created_ids: stats[:created_ids],
        updated_ids: stats[:updated_ids],
        error_details: stats[:errors],
        finished_at: Time.current
      )
    end
  rescue => e
    import_log&.update!(
      status: 'failed',
      error_details: [{ error: e.message }],
      finished_at: Time.current
    )
    Rails.cache.write("import:progress:#{session_id}", { total: 0, done: 0, complete: true, error: e.message }, expires_in: 10.minutes)
    raise
  end
end