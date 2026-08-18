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
      validator = ImportValidator.new
      @warnings = validator.validate_rows(@data)
      @validation_details = validator.validation_details(@data)
      @row_classes = validator.classify_rows(@data)
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
      sheet.add_row ImportParser::TEMPLATE_HEADERS
      sheet.add_row ["ABC123", "FAB001", "01", "Descrizione esempio", "M", "Blue", "Cotton", 80, 100, "Spring 2024", "WH01"]
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

    metadata = {}
    if params[:collection_id].present?
      c = Collection.find(params[:collection_id])
      metadata[:collection_id] = c.id
    end

    parser = ImportParser.new
    data = parser.parse(params[:file], metadata)
    data[:_collection_override_id] = metadata[:collection_id]
    data[:_file_name] = params[:file].original_filename

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
    parser = ImportParser.new
    override_collection_id = data[:_collection_override_id]

    if ImportParser::GCODE_KEYS.include?(field)
      row[:_gencode] = ImportParser.gencode_for(row)
    elsif field == ImportParser::NOTE_KEY && override_collection_id.blank?
      parser.resolve_collection(row, override_collection_id: override_collection_id)
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

  def import_bulk_collection
    data = Rails.cache.read(import_cache_key)
    return redirect_to mainware_import_path, alert: "Nessun dato da importare" unless data&.dig(:rows)&.any?

    new_name = params[:new_collection_name].to_s.strip.upcase
    if new_name.present?
      collection = Collection.find_or_create_by!(description: new_name)
    elsif params[:collection_id].present?
      collection = Collection.find(params[:collection_id])
    else
      return redirect_to mainware_import_path, alert: "Seleziona o crea una collezione."
    end

    parser = ImportParser.new
    data[:rows].each do |row|
      parser.resolve_collection(row, override_collection_id: collection.id)
      row[:_gencode] = ImportParser.gencode_for(row)
    end

    data[:_collection_override_id] = collection.id

    Rails.cache.write(import_cache_key, data, expires_in: 30.minutes)
    redirect_to mainware_import_path, notice: "Collezione '#{collection.description}' applicata a #{data[:rows].size} righe."
  end

  def import_confirm
    data = Rails.cache.read(import_cache_key)
    return redirect_to mainware_import_path, alert: "Nessun dato da importare" unless data&.dig(:rows)&.any?

    warnings = ImportValidator.new.validate_rows(data)
    return redirect_to mainware_import_path, alert: "Correggi gli errori prima di confermare: #{warnings.first}" if warnings.any?

    if params[:confirmed].present?
      begin
        persister = ImportPersister.new
        persister.ensure_dependencies!(data)
        Rails.cache.write(import_cache_key, data, expires_in: 30.minutes)

        import_log = ImportLog.create!(
          user: current_user,
          file_name: data[:_file_name],
          total_rows: data[:rows].size,
          status: 'pending',
          started_at: Time.current
        )
        Rails.cache.write("import:log:#{session.id}", import_log.id, expires_in: 10.minutes)

        total = data[:rows].size
        Rails.cache.write("import:progress:#{session.id}", { total: total, done: 0, complete: false, import_log_id: import_log.id }, expires_in: 10.minutes)
        ImportJob.perform_later(session.id.to_s)
        redirect_to mainware_import_processing_path
      rescue => e
        Rails.logger.error("Import confirm failed: #{e.message}\n#{e.backtrace.first(10).join("\n")}")
        redirect_to mainware_import_path, alert: "Errore durante l'avvio dell'importazione: #{e.message}"
      end
    else
      @summary = ImportValidator.new.summarize(data)
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

    log_id = Rails.cache.read("import:log:#{session.id}")
    @import_log = ImportLog.find_by(id: log_id)
  end

  def import_failed_rows
    stats = Rails.cache.read("import:stats:#{session.id}")
    return redirect_to mainware_index_path unless stats&.dig(:errors)&.any?

    package = Axlsx::Package.new
    wb = package.workbook
    wb.add_worksheet(name: "Errori") do |sheet|
      headers = ["Riga", "Gencode", "Errore"] + stats[:errors].first[:fields].keys.map(&:to_s)
      sheet.add_row headers
      stats[:errors].each do |err|
        sheet.add_row [err[:row], err[:gencode], err[:error]] + err[:fields].values.map(&:to_s)
      end
    end

    send_data package.to_stream.read,
      filename: "righe_errore_import.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def import_cancel
    log_id = Rails.cache.read("import:log:#{session.id}")
    ImportLog.find_by(id: log_id)&.update!(status: 'cancelled')
    Rails.cache.delete(import_cache_key)
    Rails.cache.delete("import:stats:#{session.id}")
    Rails.cache.delete("import:log:#{session.id}")
    redirect_to mainware_import_path, notice: "Importazione annullata."
  end

  def import_rollback
    stats = Rails.cache.read("import:stats:#{session.id}")
    log_id = Rails.cache.read("import:log:#{session.id}")
    import_log = ImportLog.find_by(id: log_id)
    return redirect_to mainware_index_path, alert: "Nessuna importazione da annullare" unless stats || import_log

    created_ids = import_log&.created_ids.presence || stats&.dig(:created_ids) || []
    count = created_ids.size
    ImportPersister.new.rollback({ created_ids: created_ids })
    import_log&.update!(status: 'rolled_back')
    Rails.cache.delete("import:stats:#{session.id}")
    Rails.cache.delete("import:log:#{session.id}")
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
