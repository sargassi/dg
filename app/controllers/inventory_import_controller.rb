class InventoryImportController < ApplicationController
  include InventoriesViews
  before_action -> { require_ability!('manage_inventory') }

  def import
    @data = Rails.cache.read(import_cache_key)
    @warehouses = Warehouse.all
    @locations = Location.all
    @operationtypes = Operationtype.all
  end

  def import_parse
    return redirect_to inventories_import_path, alert: "Seleziona un file" unless params[:file].present?
    return redirect_to inventories_import_path, alert: "Seleziona un tipo operazione" unless params[:operationtype_id].present?

    imports_dir = Rails.root.join("tmp", "imports")
    FileUtils.mkdir_p(imports_dir)
    file_name = params[:file].original_filename.to_s
    file_path = imports_dir.join("inv_#{session.id}_#{Time.current.to_i}_#{file_name.to_s.parameterize.first(30)}.xlsx").to_s
    FileUtils.cp(params[:file].path, file_path)

    metadata = {
      warehouse_id: params[:warehouse_id],
      location_id: params[:location_id],
      operationtype_id: params[:operationtype_id]
    }

    Rails.cache.write(import_status_key, { state: "processing" }, expires_in: 30.minutes)
    InventoryImportParseJob.perform_later(file_path, file_name, metadata, import_cache_key, import_status_key)
    redirect_to inventories_import_processing_path
  end

  def import_processing
    @status = Rails.cache.read(import_status_key)
    return redirect_to inventories_import_path if @status&.dig(:state) == "done"
    return redirect_to inventories_import_path, alert: "Nessuna importazione in corso" unless @status

    render
  end

  def import_status_json
    status = Rails.cache.read(import_status_key)
    return render json: { total: 1, done: 0, complete: false } unless status

    case status[:state]
    when "done"
      render json: { total: status[:rows], done: status[:rows], complete: true }
    when "error"
      render json: { total: 0, done: 0, complete: true, error: status[:error] }
    else
      render json: { total: 1, done: 0, complete: false }
    end
  end

  def import_update_row
    data = Rails.cache.read(import_cache_key)
    return head :not_found unless data

    row_index = params[:row_index].to_i
    field = params[:field]
    value = params[:value]

    row = data[:rows].find { |r| r[:_index] == row_index }
    return head :not_found unless row

    row[field] = value
    Rails.cache.write(import_cache_key, data, expires_in: 30.minutes)
    render json: { success: true }
  end

  def import_delete_row
    @data = Rails.cache.read(import_cache_key)
    return head :not_found unless @data

    row_index = params[:row_index].to_i
    @data[:rows].reject! { |r| r[:_index] == row_index }

    Rails.cache.write(import_cache_key, @data, expires_in: 30.minutes)
    respond_to { |format| format.turbo_stream }
  end

  def import_create_missing_items
    data = Rails.cache.read(import_cache_key)
    return redirect_to inventories_import_path, alert: "Nessun dato da importare" unless data&.dig(:rows)&.any?

    stats = ImportInventoryService.new.create_missing_items(data)
    Rails.cache.write(import_cache_key, data, expires_in: 30.minutes)

    message = "#{stats[:created]} articoli creati"
    message += ", #{stats[:failed].size} non creati" if stats[:failed].any?
    redirect_to inventories_import_path, notice: message
  end

  def import_verify
    @data = Rails.cache.read(import_cache_key)
    return redirect_to inventories_import_path, alert: "Nessun dato da importare" unless @data&.dig(:rows)&.any?
  end

  def import_confirm
    data = Rails.cache.read(import_cache_key)
    return redirect_to inventories_import_path, alert: "Nessun dato da importare" unless data&.dig(:rows)&.any?

    stats = ImportInventoryService.new.save(data, current_user)
    ImportLog.create!(
      user: current_user,
      file_name: data[:_file_name],
      total_rows: stats[:total],
      created_count: stats[:created],
      error_count: stats[:errors].size + stats[:invalid].size + stats[:skipped].size,
      created_ids: stats[:items].map { |i| i[:inventory_id] },
      error_details: (stats[:invalid] + stats[:errors]).map { |e| { row: e[:row], error: e[:error] } },
      status: stats[:errors].any? ? 'failed' : 'completed',
      started_at: Time.current,
      finished_at: Time.current
    )
    Rails.cache.delete(import_cache_key)
    Rails.cache.write(inventories_import_stats_key, stats, expires_in: 5.minutes)
    redirect_to inventories_import_summary_path
  end

  def import_summary
    @stats = Rails.cache.read(inventories_import_stats_key)
    return redirect_to inventories_path unless @stats
  end

  def import_failed_rows
    stats = Rails.cache.read(inventories_import_stats_key)
    return redirect_to inventories_path unless stats

    invalid = stats[:invalid] || []
    skipped = stats[:skipped] || []
    rows = invalid.map { |r| [r[:row], r[:itemcode], r[:error]] } +
           skipped.map { |r| [r[:row], r[:itemcode], "QTA 0 (saltato)"] }

    package = Axlsx::Package.new
    wb = package.workbook
    wb.add_worksheet(name: "Righe non importate") do |sheet|
      sheet.add_row ["Riga", "Articolo", "Errore"]
      rows.each { |row| sheet.add_row row }
    end

    send_data package.to_stream.read,
      filename: "righe_non_importate.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def import_cancel
    Rails.cache.delete(import_cache_key)
    Rails.cache.delete(import_status_key)
    redirect_to inventories_import_path, notice: "Importazione annullata."
  end

  private

  def import_cache_key
    "import:inv:#{session.id.to_s}"
  end

  def import_status_key
    "import:inv:status:#{session.id.to_s}"
  end

  def inventories_import_stats_key
    "import:inv:stats:#{session.id}"
  end
end
