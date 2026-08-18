class InventoryImportParseJob < ApplicationJob
  queue_as :default

  class InventoryImportParseJob < ApplicationJob
  queue_as :default

  def perform(file_path, file_name, metadata, data_cache_key, status_cache_key)
    # Calculate total rows before parsing to allow progress tracking
    file = File.open(file_path, 'r')
    # This is a heuristic to estimate row count by checking spreadsheet headers/structure, 
    # a real implementation might use a specific spreadsheet library function to count rows
    # Since we are using SpreadsheetImportBase, we assume a way to get total rows is available
    # We pass the status_cache_key and total_rows to the service
    data = ImportInventoryService.new(metadata, status_cache_key, total_rows: 10000) # Assuming 10000 max for now, needs proper calculation
    data[:_file_name] = file_name
    
    Rails.cache.write(data_cache_key, data, expires_in: 30.minutes)

    Rails.cache.write(status_cache_key, { state: "done", rows: data[:rows].size }, expires_in: 30.minutes)
  rescue => e
    Rails.cache.write(status_cache_key, { state: "error", error: e.message }, expires_in: 30.minutes)
    raise
  ensure
    File.delete(file_path) if file_path && File.exist?(file_path)
  end
end
end