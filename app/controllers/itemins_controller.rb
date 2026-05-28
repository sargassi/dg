class IteminsController < ApplicationController
  before_action -> { require_ability!('manage_itemins') }
  before_action :set_itemin, only: %i[ show edit update destroy ]
  before_action :load_warehouses_locations_operationtypes, only: %i[ new edit ]

  # GET /itemins or /itemins.json
  def index
    @itemins = Itemin.all
  end

  # GET /itemins/1 or /itemins/1.json
  def show
  end

  # GET /itemins/new
  def new
    if session[:itemin_preview].present?
      preview = session[:itemin_preview]
      @itemin = Itemin.new(indate: preview["indate"], notes: preview["notes"])
      details = (preview["itemins_details_attributes"] || {}).values
        .reject { |d| d["_destroy"] == "1" }
        .reject { |d| d["itemcode"].blank? && d["item_id"].blank? }
        .map { |d| d.except("_destroy") }
      @itemin.itemins_details.build(details)
    else
      @itemin = Itemin.new(indate: Date.current)
    end
  end

  # GET /itemins/1/edit
  def edit
  end

  # POST /inventories/itemins
  def create
    @itemin = Itemin.new(indate: itemin_params[:indate], notes: itemin_params[:notes], operator_id: itemin_params[:operator_id])

    details = (itemin_params[:itemins_details_attributes]&.values || []).reject { |d| d[:_destroy] == "1" }.reject { |d| d[:itemcode].blank? && d[:item_id].blank? }.map { |d| d.except(:_destroy) }
    @itemin.itemins_details.build(details)

    if @itemin.valid?
      session[:itemin_preview] = itemin_params.to_unsafe_h
      @params = itemin_params.to_unsafe_h.with_indifferent_access
      load_preview_data

      respond_to do |format|
        format.html { redirect_to preview_itemins_path, notice: "Anteprima carico pronta" }
        format.turbo_stream { redirect_to preview_itemins_path, notice: "Anteprima carico pronta" }
      end
    else
      load_warehouses_locations_operationtypes
      flash.now[:alert] = @itemin.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  # GET /inventories/itemins/preview
  def preview
    @params = session[:itemin_preview]&.with_indifferent_access
    return redirect_to new_itemin_path, alert: "Nessun dato in anteprima" unless @params

    load_preview_data
  end

  # POST /inventories/itemins/confirm
  def confirm
    @params = session[:itemin_preview]&.with_indifferent_access
    return redirect_to new_itemin_path, alert: "Nessun dato, riprova" unless @params

    @itemin = Itemin.new(@params.except(:itemins_details_attributes))

    details = (@params[:itemins_details_attributes] || {}).values
      .reject { |d| d["_destroy"] == "1" }
      .map { |d| d.slice("itemcode", "qty", "item_id", "collection_id", "warehouse_id", "location_id", "operationtype_id") }
    @itemin.itemins_details.build(details)

    begin
      ActiveRecord::Base.transaction do
        @itemin.save!
        CreateInventoriesFromItemin.new.call(@itemin)
      end

      session.delete(:itemin_preview)
      redirect_to inventories_dashboard_path, notice: "Carico creato con #{@itemin.itemins_details.size} articoli"
    rescue => e
      redirect_to new_itemin_path, alert: "Errore durante il salvataggio: #{e.message}"
    end
  end

  # PATCH/PUT /itemins/1 or /itemins/1.json
  def update
    respond_to do |format|
      if @itemin.update(itemin_params)
        format.html { redirect_to itemin_url(@itemin), notice: "Itemin was successfully updated." }
        format.json { render :show, status: :ok, location: @itemin }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @itemin.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /itemins/1 or /itemins/1.json
  def destroy
    @itemin.destroy

    respond_to do |format|
      format.html { redirect_to itemins_url, notice: "Itemin was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    def set_itemin
      @itemin = Itemin.find(params[:id])
    end

    def load_warehouses_locations_operationtypes
      @warehouses = Warehouse.all
      @locations = Location.all
      @operationtypes = Operationtype.all
    end

    def load_preview_data
      @details = (@params[:itemins_details_attributes] || {}).values.reject { |d| d[:_destroy] == "1" }
      warehouse_ids = @details.map { |d| d[:warehouse_id] }.compact.uniq
      location_ids = @details.map { |d| d[:location_id] }.compact.uniq
      operationtype_ids = @details.map { |d| d[:operationtype_id] }.compact.uniq
      @warehouse_idx = Warehouse.where(id: warehouse_ids).index_by { |w| w.id.to_s }
      @location_idx = Location.where(id: location_ids).index_by { |l| l.id.to_s }
      @operationtype_idx = Operationtype.where(id: operationtype_ids).index_by { |o| o.id.to_s }
      @operator = User.find_by(id: @params[:operator_id])
    end

    def itemin_params
      params.require(:itemin).permit(:indate, :notes, :operator_id,
        itemins_details_attributes: [:id, :itemcode, :qty, :item_id, :collection_id, :warehouse_id, :location_id, :operationtype_id, :_destroy])
    end
end