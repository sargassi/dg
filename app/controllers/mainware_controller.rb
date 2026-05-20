class MainwareController < ApplicationController
  include Pagy::Backend

  def index
    @collections = Collection.joins("INNER JOIN items ON items.collection_id = collections.id").distinct.order(created_at: :desc)

    @itemz = Item.all

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
  end



  def dashboard
    @items_count = Item.count
    @warehouses_count = Warehouse.count
    @locations_count = Location.count
  end

  def import
    @data = Rails.cache.read(import_cache_key)
    @collections = Collection.all
  end

  def import_parse
    return redirect_to mainware_import_path, alert: "Seleziona un file" unless params[:file].present?
    return redirect_to mainware_import_path, alert: "Seleziona una collezione" unless params[:collection_id].present?

    service = ImportGeneralService.new
    data = service.parse(params[:file], params[:collection_id])
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

    if ['Item Code:', 'Fabric code:', 'var. code:'].include?(field)
      row[:_gencode] = [row['Item Code:'], row['Fabric code:'], row['var. code:']].map(&:to_s).join
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

         stats = ImportGeneralService.new.save(data)
         Rails.cache.delete(import_cache_key)
         Rails.cache.write("import:stats:#{session.id}", stats, expires_in: 5.minutes)
         redirect_to mainware_import_summary_path
       end
  def import_summary
    @stats = Rails.cache.read("import:stats:#{session.id}")
    return redirect_to mainware_index_path unless @stats
  end

  def import_cancel
    Rails.cache.delete(import_cache_key)
    redirect_to mainware_import_path, notice: "Importazione annullata."
  end

  def stage

  end

  def search
  end

  def searchqr
  end

  private

  def import_cache_key
    "import:#{session.id.to_s}"
  end

end
