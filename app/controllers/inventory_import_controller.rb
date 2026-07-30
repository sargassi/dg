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

    service = ImportInventoryService.new
    data = service.parse(params[:file],
      warehouse_id: params[:warehouse_id],
      location_id: params[:location_id],
      operationtype_id: params[:operationtype_id])
    Rails.cache.write(import_cache_key, data, expires_in: 30.minutes)
    Rails.cache.delete(inventories_import_stats_key)
    redirect_to inventories_import_path, notice: "#{data[:rows].size} righe caricate. Verifica e modifica."
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

  def import_verify
    @data = Rails.cache.read(import_cache_key)
    return redirect_to inventories_import_path, alert: "Nessun dato da importare" unless @data&.dig(:rows)&.any?
  end

  def import_confirm
    data = Rails.cache.read(import_cache_key)
    return redirect_to inventories_import_path, alert: "Nessun dato da importare" unless data&.dig(:rows)&.any?

    stats = ImportInventoryService.new.save(data, current_user)
    Rails.cache.delete(import_cache_key)
    Rails.cache.write(inventories_import_stats_key, stats, expires_in: 5.minutes)
    redirect_to inventories_import_summary_path
  end

  def import_summary
    @stats = Rails.cache.read(inventories_import_stats_key)
    return redirect_to inventories_path unless @stats
  end

  def import_cancel
    Rails.cache.delete(import_cache_key)
    redirect_to inventories_import_path, notice: "Importazione annullata."
  end

  private

  def import_cache_key
    "import:inv:#{session.id.to_s}"
  end

  def inventories_import_stats_key
    "import:inv:stats:#{session.id}"
  end
end
