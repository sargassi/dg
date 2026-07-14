class ItemoutsController < ApplicationController
  before_action -> { require_ability!('manage_itemouts') }
  before_action :set_itemout, only: %i[ show edit update destroy ]

  def index
    @itemouts = Itemout.all
  end

  def show
  end

  def new
    if session[:itemout_preview].present?
      preview = session[:itemout_preview]
      @itemout = Itemout.new(indate: preview["indate"], notes: preview["notes"])
      details = (preview["itemouts_details_attributes"] || {}).values
        .reject { |d| d["_destroy"] == "1" }
        .reject { |d| d["itemcode"].blank? && d["item_id"].blank? }
        .map { |d| d.except("_destroy") }
      @itemout.itemouts_details.build(details)
    elsif session[:archive_itemout_prefill].present?
      @itemout = Itemout.new(indate: Date.current, operator: current_user)
      session[:archive_itemout_prefill].each do |data|
        @itemout.itemouts_details.build(
          itemcode: data["gencode"],
          item_id: data["item_id"],
          collection_id: data["collection_id"],
          qty: data["qty"] || 1,
          operationtype_id: 2
        )
      end
      session.delete(:archive_itemout_prefill)
    else
      @itemout = Itemout.new(indate: Date.current)
    end
    @warehouses = Warehouse.all
    @locations = Location.all
    @operationtypes = Operationtype.all
  end

  def edit
  end

  def create
    @itemout = Itemout.new(indate: itemout_params[:indate], notes: itemout_params[:notes], operator_id: itemout_params[:operator_id])
    details = (itemout_params[:itemouts_details_attributes]&.values || []).reject { |d| d[:_destroy] == "1" }.reject { |d| d[:itemcode].blank? && d[:item_id].blank? }.map { |d| d.except(:_destroy) }

    validate_stock_availability(details)

    if @itemout.valid?
      session[:itemout_preview] = itemout_params.to_unsafe_h
      @params = itemout_params.to_unsafe_h.with_indifferent_access
      @details = (@params[:itemouts_details_attributes] || {}).values.reject { |d| d[:_destroy] == "1" }

      respond_to do |format|
        format.html { redirect_to preview_itemouts_path, notice: "Anteprima scarico pronta" }
        format.turbo_stream { redirect_to preview_itemouts_path, notice: "Anteprima scarico pronta" }
      end
    else
      @warehouses = Warehouse.all
      @locations = Location.all
      @operationtypes = Operationtype.all
      flash.now[:alert] = @itemout.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def preview
    @params = session[:itemout_preview]&.with_indifferent_access
    return redirect_to new_itemout_path, alert: "Nessun dato in anteprima" unless @params

    @details = (@params[:itemouts_details_attributes] || {}).values.reject { |d| d[:_destroy] == "1" }
  end

  def confirm
    @params = session[:itemout_preview]&.with_indifferent_access
    return redirect_to new_itemout_path, alert: "Nessun dato, riprova" unless @params

    @itemout = Itemout.new(indate: @params[:indate], notes: @params[:notes], operator_id: @params[:operator_id])

    details = (@params[:itemouts_details_attributes] || {}).values
      .reject { |d| d["_destroy"] == "1" }
      .map { |d| d.slice("itemcode", "qty", "item_id", "collection_id", "warehouse_id", "location_id", "operationtype_id") }
    @itemout.itemouts_details.build(details)

    begin
      ActiveRecord::Base.transaction do
        @itemout.save!
        CreateInventoriesFromItemout.new.call(@itemout)
      end

      session.delete(:itemout_preview)
      redirect_to inventories_dashboard_path, notice: "Scarico creato con #{@itemout.itemouts_details.size} articoli"
    rescue => e
      redirect_to new_itemout_path, alert: "Errore durante il salvataggio: #{e.message}"
    end
  end

  def update
    respond_to do |format|
      if @itemout.update(itemout_params)
        format.html { redirect_to itemout_url(@itemout), notice: "Itemout was successfully updated." }
        format.json { render :show, status: :ok, location: @itemout }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @itemout.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @itemout.destroy

    respond_to do |format|
      format.html { redirect_to itemouts_url, notice: "Itemout was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def import
    @data = Rails.cache.read(import_cache_key)
  end

  def import_parse
    return redirect_to import_itemouts_path, alert: "Seleziona un file" unless params[:file].present?

    service = ImportItemoutService.new
    data = service.parse(params[:file])
    Rails.cache.write(import_cache_key, data, expires_in: 30.minutes)
    redirect_to import_itemouts_path, notice: "#{data[:rows].size} righe caricate. Verifica e conferma."
  end

  def import_confirm
    data = Rails.cache.read(import_cache_key)
    return redirect_to import_itemouts_path, alert: "Nessun dato da importare" unless data&.dig(:rows)&.any?

    stats = ImportItemoutService.new.save(data, current_user)
    Rails.cache.delete(import_cache_key)

    if stats[:errors].any?
      redirect_to inventories_dashboard_path, alert: "Importazione completata con #{stats[:created]} articoli. #{stats[:errors].size} errori."
    else
      redirect_to inventories_dashboard_path, notice: "Importazione uscite completata: #{stats[:created]} articoli su #{stats[:total]}."
    end
  end

  def import_cancel
    Rails.cache.delete(import_cache_key)
    redirect_to import_itemouts_path, notice: "Importazione annullata."
  end

  private
    def validate_stock_availability(details)
      item_ids = details.map { |d| d[:item_id] }.compact.uniq
      items = Item.where(id: item_ids).index_by(&:id)
      gencodes = items.values.map(&:gencode).compact.uniq

      stock = StockLevel.where(gencode: gencodes)
        .each_with_object({}) { |sl, h| h[[sl.gencode, sl.warehouse_id, sl.location_id]] = sl.current_qty }

      details.each do |d|
        next unless d[:item_id]
        item = items[d[:item_id].to_i]
        next unless item

        available = stock[[item.gencode, d[:warehouse_id].to_i, d[:location_id].to_i]] || 0
        if d[:qty].to_i > available
          @itemout.errors.add(:base, "#{item.gencode}: quantità #{d[:qty]} supera la disponibilità (#{available} pz)")
        end
      end
    end

    def set_itemout
      @itemout = Itemout.find(params[:id])
    end

    def itemout_params
      params.require(:itemout).permit(:indate, :notes, :operator_id,
        itemouts_details_attributes: [:id, :itemcode, :qty, :item_id, :collection_id, :warehouse_id, :location_id, :operationtype_id, :_destroy])
    end

    def import_cache_key
      "import_itemout:#{session.id.to_s}"
    end
end
