class MainwareController < ApplicationController
  include Pagy::Backend
  before_action -> { require_ability!('manage_mainware') }

  def index
    @collections = Collection.joins("INNER JOIN items ON items.collection_id = collections.id").distinct.order(row_order: :desc)

    siblings_count_sql = "(SELECT COUNT(*) FROM items AS s WHERE s.itemcode = items.itemcode AND s.fabricode = items.fabricode AND s.varcode = items.varcode)"
    @itemz = Item.select("items.*, #{siblings_count_sql} AS siblings_count")

    if params[:collection_id].present?
      @collection_id = params[:collection_id]
      @itemz = @itemz.where(collection_id: @collection_id)
    elsif !params.key?(:collection_id) && @collections.any?
      @collection_id = @collections.first.id.to_s
      @itemz = @itemz.where(collection_id: @collections.first.id)
    end

    if params[:q].present?
      q = "%#{params[:q]}%"
      @itemz = @itemz.where(
        "gencode LIKE :q OR itemcode LIKE :q OR fabricode LIKE :q OR varcode LIKE :q OR description LIKE :q OR fabric LIKE :q OR colour LIKE :q",
        q: q
      )
    end
    @pagy, @itemz = pagy(@itemz)

    base_keys = @itemz.pluck(:itemcode, :fabricode, :varcode).uniq
    if base_keys.any? && @collection_id.present?
      item_ids = @itemz.map(&:id)
      sibling_ids = {}
      base_keys.each_slice(50) do |batch|
        t = Item.arel_table
        condition = batch.map { |ic, fc, vc|
          t[:itemcode].eq(ic).and(t[:fabricode].eq(fc).and(t[:varcode].eq(vc)))
        }.reduce(:or)
        Item.where(condition).where.not(id: item_ids).pluck(:id).each { |id| sibling_ids[id] = true }
      end

      @siblings_by_parent = Item.where(id: sibling_ids.keys)
                                .includes(:collection)
                                .order("collections.created_at DESC")
                                .group_by { |s| [s.itemcode, s.fabricode, s.varcode] }
    else
      @siblings_by_parent = {}
    end
  end



  def prices_compare
    items = Item.includes(:collection).order(:itemcode, :fabricode, :varcode, "collections.created_at DESC")

    if params[:q].present?
      q = "%#{params[:q]}%"
      items = items.where(
        "items.gencode LIKE :q OR items.itemcode LIKE :q OR items.fabricode LIKE :q OR items.varcode LIKE :q OR items.description LIKE :q OR items.fabric LIKE :q OR items.colour LIKE :q",
        q: q
      )
    end

    groups = items.group_by { |i| [i.itemcode, i.fabricode, i.varcode] }

    @grouped_items = groups.sort_by { |(ic, fc, vc), _| [ic.to_s, fc.to_s, vc.to_s] }
  end

  def dashboard
    @items_count = Item.count
    @collections_count = Collection.count
    @warehouses_count = Warehouse.count
    @locations_count = Location.count
  end

  def import
    @data = Rails.cache.read(import_cache_key)
    @collections = Collection.all.order(:description)
    if @data
      service = ImportGeneralService.new
      @warnings = service.validate_rows(@data)
      @validation_details = service.validation_details(@data)
      @row_classes = service.classify_rows(@data)
    else
      @warnings = []
      @validation_details = {}
      @row_classes = {}
    end
  end

  def import_template
    package = Axlsx::Package.new
    wb = package.workbook
    wb.add_worksheet(name: "Template") do |sheet|
      sheet.add_row ImportGeneralService::TEMPLATE_HEADERS
      sheet.add_row ["ABC123", "FAB001", "01", "Descrizione esempio", "M", "Blue", "Cotton", 100, "Spring 2024", "WH01"]
    end
    send_data package.to_stream.read,
      filename: "template_import_articoli.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def import_parse
    return redirect_to mainware_import_path, alert: "Seleziona un file" unless params[:file].present?

    allowed_types = [
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "application/octet-stream"
    ].freeze

    unless params[:file].original_filename.to_s.downcase.end_with?(".xlsx") || allowed_types.include?(params[:file].content_type)
      return redirect_to mainware_import_path, alert: "Il file deve essere in formato .xlsx"
    end

    if params[:file].size > 5.megabytes
      return redirect_to mainware_import_path, alert: "Il file è troppo grande (massimo 5 MB)"
    end

    metadata = {}
    if params[:collection_id].present?
      c = Collection.find(params[:collection_id])
      metadata[:collection_id] = c.id
    end

    service = ImportGeneralService.new
    data = service.parse(params[:file], metadata)
    data[:_collection_override_id] = metadata[:collection_id]

    Rails.cache.write(import_cache_key, data, expires_in: 30.minutes)
    redirect_to mainware_import_path, notice: "#{data[:rows].size} righe caricate. Verifica e modifica."
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
    service = ImportGeneralService.new
    override_collection_id = data[:_collection_override_id]

    if ['Item Code:', 'Fabric code:', 'var. code:'].include?(field)
      coll_id = row[:_collection_id]
      row[:_gencode] = [row['Item Code:'], row['Fabric code:'], row['var. code:']].map(&:to_s).join + "_#{coll_id}"
    elsif field == 'Note:' && override_collection_id.blank?
      service.resolve_collection(row, override_collection_id: override_collection_id)
    elsif field == 'dove'
      service.resolve_warehouse(row)
    end

    Rails.cache.write(import_cache_key, data, expires_in: 30.minutes)
    render json: { success: true, gencode: row[:_gencode] }
  end

  def import_delete_row
    data = Rails.cache.read(import_cache_key)
    return head :not_found unless data

    row_index = params[:row_index].to_i
    data[:rows].reject! { |r| r[:_index] == row_index }

    Rails.cache.write(import_cache_key, data, expires_in: 30.minutes)
    respond_to { |format| format.turbo_stream }
  end

  def import_confirm
    data = Rails.cache.read(import_cache_key)
    return redirect_to mainware_import_path, alert: "Nessun dato da importare" unless data&.dig(:rows)&.any?

    warnings = ImportGeneralService.new.validate_rows(data)
    return redirect_to mainware_import_path, alert: "Correggi gli errori prima di confermare: #{warnings.first}" if warnings.any?

    if params[:confirmed].present?
      service = ImportGeneralService.new
      service.ensure_dependencies!(data)
      Rails.cache.write(import_cache_key, data, expires_in: 30.minutes)

      total = data[:rows].size
      Rails.cache.write("import:progress:#{session.id}", { total: total, done: 0, complete: false }, expires_in: 10.minutes)
      ImportJob.perform_later(session.id.to_s)
      redirect_to mainware_import_processing_path
    else
      @summary = ImportGeneralService.new.summarize(data)
      render
    end
  end

  def import_processing
    @progress = Rails.cache.read("import:progress:#{session.id}")
    return redirect_to mainware_index_path unless @progress
  end

  def import_progress_json
    progress = Rails.cache.read("import:progress:#{session.id}")
    if progress
      render json: progress
    else
      render json: { total: 0, done: 0, complete: false }
    end
  end

  def import_summary
    @stats = Rails.cache.read("import:stats:#{session.id}")
    return redirect_to mainware_index_path unless @stats
  end

  def import_cancel
    Rails.cache.delete(import_cache_key)
    redirect_to mainware_import_path, notice: "Importazione annullata."
  end

  def import_rollback
    stats = Rails.cache.read("import:stats:#{session.id}")
    return redirect_to mainware_index_path, alert: "Nessuna importazione da annullare" unless stats

    count = stats[:created_ids]&.size || 0
    ImportGeneralService.new.rollback(stats)
    Rails.cache.delete("import:stats:#{session.id}")
    redirect_to mainware_index_path, notice: "Rollback completato: #{count} articoli eliminati."
  end

  def searchqr
    if params[:q].present?
      raw_q = params[:q].to_s.strip
      gencode = parse_qr_gencode(raw_q)

      siblings_count_sql = "(SELECT COUNT(*) FROM items AS s WHERE s.itemcode = items.itemcode AND s.fabricode = items.fabricode AND s.varcode = items.varcode)"
      @itemz = Item.select("items.*, #{siblings_count_sql} AS siblings_count").includes(:collection)

      @itemz = @itemz.where(gencode: gencode)
      if @itemz.none?
        q = "%#{gencode}%"
        @itemz = Item.select("items.*, #{siblings_count_sql} AS siblings_count").includes(:collection)
        @itemz = @itemz.where(
          "items.gencode LIKE :q OR items.itemcode LIKE :q OR items.fabricode LIKE :q OR items.varcode LIKE :q OR items.description LIKE :q OR items.fabric LIKE :q OR items.colour LIKE :q",
          q: q
        )
      end

      base_keys = @itemz.pluck(:itemcode, :fabricode, :varcode).uniq
      if base_keys.any?
        item_ids = @itemz.map(&:id)
        sibling_ids = {}
        base_keys.each_slice(50) do |batch|
          t = Item.arel_table
          condition = batch.map { |ic, fc, vc|
            t[:itemcode].eq(ic).and(t[:fabricode].eq(fc).and(t[:varcode].eq(vc)))
          }.reduce(:or)
          Item.where(condition).where.not(id: item_ids).pluck(:id).each { |id| sibling_ids[id] = true }
        end

        @siblings_by_parent = Item.where(id: sibling_ids.keys)
                                  .includes(:collection)
                                  .order("collections.created_at DESC")
                                  .group_by { |s| [s.itemcode, s.fabricode, s.varcode] }
      else
        @siblings_by_parent = {}
      end
    else
      @itemz = Item.none
      @siblings_by_parent = {}
    end
  end

  private

  def parse_qr_gencode(text)
    QrParser.parse(text)[:gencode]
  end

  def import_cache_key
    "import:#{session.id.to_s}"
  end

end
