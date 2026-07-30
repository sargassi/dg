class CollectionsController < ApplicationController
  before_action -> { require_ability!('manage_collections') }
  before_action :set_collection, only: %i[ show edit update destroy ]

  # GET /collections or /collections.json
  def index
    @collections = Collection.all.order(:description)
    @collection = Collection.new
  end

  # GET /collections/1 or /collections/1.json
  def show
  end

  # GET /collections/new
  def new
    @collection = Collection.new
  end

  # GET /collections/1/edit
  def edit
  end

  # POST /collections or /collections.json
  def create
    @collection = Collection.new(collection_params)

    respond_to do |format|
      if @collection.save
        format.html { redirect_to collections_url, notice: "Collection was successfully created." }
        format.json { render :show, status: :created, location: @collection }
      else
        @collections = Collection.all.order(:description)
        format.html { render :index, status: :unprocessable_entity }
        format.json { render json: @collection.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /collections/1 or /collections/1.json
  def update
    respond_to do |format|
      if @collection.update(collection_params)
        format.html { redirect_to collections_url, notice: "Collection was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @collection }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @collection.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /collections/1 or /collections/1.json
  def destroy
    if @collection.items.any?
      redirect_to collections_path, alert: "Impossibile eliminare '#{@collection.description}': ci sono #{@collection.items.count} articoli associati."
      return
    end

    @collection.destroy!

    respond_to do |format|
      format.html { redirect_to collections_path, notice: "Collezione eliminata con successo.", status: :see_other }
      format.turbo_stream { redirect_to collections_path, notice: "Collezione eliminata con successo." }
      format.json { head :no_content }
    end
  end

  def reorder
    params.require(:ids).each_with_index do |id, index|
      Collection.where(id: id).update_all(row_order: index)
    end
    head :ok
  end

  def merge
    @collections = Collection.order(:description)
  end

  def merge_apply
    source_ids = params[:source_ids]
    target_id = params[:target_id]

    result = MergeCollectionsService.new.call(source_ids: source_ids, target_id: target_id)

    if result.success
      redirect_to collections_path, notice: "Unione completata. #{result.stats[:items_moved]} articoli spostati, #{result.stats[:collections_removed]} collezioni rimosse."
    else
      redirect_to merge_collections_path, alert: result.error
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_collection
      @collection = Collection.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def collection_params
      params.require(:collection).permit(:description, :row_order)
    end
end
