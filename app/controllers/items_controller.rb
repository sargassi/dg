class ItemsController < ApplicationController
  before_action :set_item, only: %i[ show edit update destroy delete_picture gallery ]

  # GET /items or /items.json
  def index
    @items = Item.all
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
        format.html { redirect_to item_url(@item), notice: "Item was successfully created." }
        format.json { render :show, status: :created, location: @item }
      else
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
        format.html { redirect_to mainware_index_path, notice: "Item was successfully updated." }
        format.json { render :show, status: :ok, location: @item }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @item.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /items/1/gallery
  def gallery
    @index = (params[:index] || 0).to_i
    @pictures = @item.pictures
    render layout: false
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
      redirect_to mainware_index_path, notice: "Immagine rimossa."
    end
  end

  # DELETE /items/1 or /items/1.json
  def destroy
    @item.destroy

    respond_to do |format|
      format.html { redirect_to mainware_index_path, notice: "Item was successfully destroyed." }
      format.turbo_stream { redirect_to mainware_index_path, notice: "Item was successfully destroyed." }
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
