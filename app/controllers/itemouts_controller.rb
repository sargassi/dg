class ItemoutsController < ApplicationController
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

  private
    def validate_stock_availability(details)
      item_ids = details.map { |d| d[:item_id] }.compact.uniq
      items = Item.where(id: item_ids).index_by(&:id)
      gencodes = items.values.map(&:gencode).compact.uniq

      net_qty_by_key = Inventory.where(gencode: gencodes)
        .group(:gencode, :warehouse_id, :location_id)
        .select(
          :gencode, :warehouse_id, :location_id,
          Arel.sql("SUM(CASE WHEN operationtype_id = 1 THEN COALESCE(qtyavailable, 0) ELSE 0 END) - SUM(CASE WHEN operationtype_id = 2 THEN COALESCE(qtyavailable, 0) ELSE 0 END) AS net_qty")
        )
        .each_with_object({}) { |row, h| h[[row.gencode, row.warehouse_id, row.location_id]] = row.net_qty }

      details.each do |d|
        next unless d[:item_id]
        item = items[d[:item_id].to_i]
        next unless item

        available = net_qty_by_key[[item.gencode, d[:warehouse_id].to_i, d[:location_id].to_i]] || 0
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
end
