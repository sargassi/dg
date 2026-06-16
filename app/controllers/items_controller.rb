class ItemsController < ApplicationController
  before_action -> { require_ability!('manage_items') }
  before_action :set_item, only: %i[ show edit update destroy delete_picture gallery price_history ]

  # GET /items or /items.json
  def index
    @items = Item.all
  end

  # GET /items/distinct_values?field=itemcode&q=xxx
  def distinct_values
    allowed = %w[itemcode fabricode varcode]
    return head :bad_request unless allowed.include?(params[:field])

    q = "%#{params[:q]}%"
    values = Item.where(Item.arel_table[params[:field]].matches(q))
                 .distinct
                 .limit(20)
                 .pluck(params[:field])
                 .map { |v| v.presence }
                 .compact

    render json: values
  end

  # GET /items/autocomplete
  def autocomplete
    q = "%#{params[:q]}%"
    @items = Item.includes(:collection).where(
      "gencode LIKE :q OR itemcode LIKE :q OR fabricode LIKE :q OR varcode LIKE :q",
      q: q
    )
    if params[:collection_id].present?
      @items = @items.where(collection_id: params[:collection_id])
    end
    @items = @items.select(:id, :gencode, :itemcode, :fabricode, :varcode, :description, :collection_id, :tg, :fabric, :colour, :materiale).limit(20)
    render json: @items.map { |item|
      { id: item.id, gencode: item.gencode, itemcode: item.itemcode, fabricode: item.fabricode, varcode: item.varcode, description: item.description, label: "#{item.gencode} — #{item.description}", collection: item.collection&.description, collection_id: item.collection_id, tg: item.tg, fabric: item.fabric, colour: item.colour, materiale: item.materiale }
    }
  end

  # GET /items/1 or /items/1.json
  def show
  end

  # GET /items/new
  def new
    @item = Item.new
    @collections = Collection.all
  end

  # GET /items/1/edit
  def edit
    @collections = Collection.all
  end

  # POST /items or /items.json
  def create
    @item = Item.new(item_params)

    respond_to do |format|
      if @item.save
        format.html { redirect_to create_confirmation_items_path(item_id: @item.id) }
        format.json { render :show, status: :created, location: @item }
      else
        @collections = Collection.all
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @item.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /items/1 or /items/1.json
  def update
    if params[:item][:pictures].present?
      kept_signed = params[:item][:pictures].select { |p| p.is_a?(String) && p.present? }
      new_files = params[:item][:pictures].select { |p| p.respond_to?(:original_filename) }
      @item.pictures.each { |pic| pic.purge unless kept_signed.include?(pic.signed_id) }
      @item.pictures.attach(new_files) if new_files.any?
    end
    respond_to do |format|
      if @item.update(item_params.except(:pictures))
        format.html { redirect_to params[:return_to].presence || mainware_index_path(q: params[:q], collection_id: params[:collection_id]), notice: "Item was successfully updated." }
        format.json { render :show, status: :ok, location: @item }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @item.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /items/create_confirmation
  def create_confirmation
    @item = Item.find(params[:item_id])
  end

  # GET /items/1/gallery
  def gallery
    @index = (params[:index] || 0).to_i
    @pictures = @item.pictures
    render layout: false
  end

  # GET /items/1/price_history
  def price_history
    @siblings = Item.where(
      itemcode: @item.itemcode,
      fabricode: @item.fabricode,
      varcode: @item.varcode
    ).includes(:collection).order("collections.created_at DESC")
    render partial: "items/price_history", locals: { siblings: @siblings }
  end

  # DELETE /items/1/delete_picture
  def delete_picture
    deleted_index = (params[:index] || 0).to_i
    pic = @item.pictures.find(params[:picture_id])
    pic.purge
    if @item.pictures.reload.any?
      target = deleted_index >= @item.pictures.count ? @item.pictures.count - 1 : deleted_index
      target = 0 if target < 0
      redirect_to gallery_item_path(@item, index: target), notice: "Immagine rimossa."
    else
      redirect_to mainware_index_path(q: params[:q], collection_id: params[:collection_id]), notice: "Immagine rimossa."
    end
  end

  # DELETE /items/1 or /items/1.json
  def destroy
    @item.destroy

    respond_to do |format|
      format.html { redirect_to params[:return_to].presence || mainware_index_path(q: params[:q], collection_id: params[:collection_id]), notice: "Item was successfully destroyed." }
      format.turbo_stream { redirect_to params[:return_to].presence || mainware_index_path(q: params[:q], collection_id: params[:collection_id]), notice: "Item was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_item
      @item = Item.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def item_params
      params.require(:item).permit(:itemcode, :fabricode, :varcode, :description, :tg, :note, :fabric, :colour, :unit_price, :gencode, :materiale, :collection_id, pictures: [])
    end
end
