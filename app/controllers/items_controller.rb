class ItemsController < ApplicationController
  before_action -> { require_ability!('manage_items') }, except: [:autocomplete]
  before_action :set_item, only: %i[ show edit update destroy delete_picture gallery price_history ]

  # GET /items or /items.json
  def index
    @items = Item.all
  end

  # GET /items/distinct_values?field=itemcode&q=xxx
  # Filters: itemcode=XXX narrows fabricode/varcode values to items with that itemcode;
  # fabricode=XXX narrows varcode values to items with that itemcode+fabricode.
  def distinct_values
    allowed = %w[itemcode fabricode varcode]
    return head :bad_request unless allowed.include?(params[:field])

    scope = Item.all
    scope = scope.where(itemcode: params[:itemcode]) if params[:itemcode].present?
    scope = scope.where(fabricode: params[:fabricode]) if params[:fabricode].present?

    q = "%#{params[:q]}%"
    limit = params[:limit].present? ? params[:limit].to_i.clamp(1, 500) : 20
    values = scope.where(Item.arel_table[params[:field]].matches(q))
                  .distinct
                  .order(params[:field] => :asc)
                  .limit(limit)
                  .pluck(params[:field])
                  .map { |v| v.presence }
                  .compact

    render json: values
  end

  # GET /items/value_info?field=fabricode|varcode&value=xxx&itemcode=yyy&fabricode=zzz
  # Reports whether a fabricode/varcode already exists OUTSIDE the current
  # itemcode (+fabricode) combination, so the wizard can warn before creating a new code.
  def value_info
    allowed = %w[fabricode varcode]
    return head :bad_request unless allowed.include?(params[:field])
    value = params[:value].to_s.strip
    return head :bad_request if value.empty?

    scope = Item.where(Item.arel_table[params[:field]].eq(value))
    case params[:field]
    when "fabricode"
      scope = scope.where.not(itemcode: params[:itemcode]) if params[:itemcode].present?
    when "varcode"
      if params[:itemcode].present? || params[:fabricode].present?
        scope = scope.where.not(itemcode: params[:itemcode], fabricode: params[:fabricode])
      end
    end

    render json: { exists: scope.exists?, count: scope.count }
  end

  # GET /items/combination
  def combination
    @item = Item.new
    @collections = Collection.all
    render layout: false
  end

  # GET /items/combination_info?itemcode=X&fabricode=Y&varcode=Z&collection_id=N
  def combination_info
    itemcode = params[:itemcode].to_s.strip
    fabricode = params[:fabricode].to_s.strip
    varcode = params[:varcode].to_s.strip
    return head :bad_request if [itemcode, fabricode, varcode].all?(&:empty?)

    composed = [itemcode, fabricode, varcode].join
    collection_id = params[:collection_id].presence
    exclude_id = params[:exclude_id].presence

    siblings_scope = Item
      .where(itemcode: itemcode, fabricode: fabricode, varcode: varcode)
      .where.not(itemcode: [nil, ""]).where.not(fabricode: [nil, ""]).where.not(varcode: [nil, ""])
    if itemcode.empty? || fabricode.empty? || varcode.empty?
      siblings_scope = Item.none
    end
    siblings_scope = siblings_scope.where.not(id: exclude_id) if exclude_id.present?
    siblings_scope = siblings_scope.where.not(collection_id: collection_id) if collection_id.present?

    gencode = collection_id.present? ? "#{composed}_#{collection_id}" : nil
    exact_exists = gencode.present? &&
      Item.where(gencode: gencode).where.not(id: exclude_id).exists?

    siblings = siblings_scope
      .includes(:collection)
      .order("collections.created_at DESC")
      .map do |item|
        {
          collection_id: item.collection_id,
          collection: item.collection&.description,
          unit_price: item.unit_price,
          vendita: item.vendita
        }
      end

    suggestion = nil
    if itemcode.present? && fabricode.present? && varcode.present?
      suggestion = Item.where(itemcode: itemcode, fabricode: fabricode, varcode: varcode)
        .includes(:collection).order("collections.created_at DESC").first
    end
    if suggestion.nil? && itemcode.present? && fabricode.present?
      suggestion = Item.where(itemcode: itemcode, fabricode: fabricode)
        .includes(:collection).order("collections.created_at DESC").first
    end
    if suggestion.nil? && itemcode.present?
      suggestion = Item.where(itemcode: itemcode)
        .includes(:collection).order("collections.created_at DESC").first
    end
    if suggestion.nil? && fabricode.present?
      suggestion = Item.where(fabricode: fabricode)
        .includes(:collection).order("collections.created_at DESC").first
    end

    render json: {
      composed: composed,
      gencode: gencode,
      exact_exists: exact_exists,
      siblings: siblings,
      suggestions: suggestion && {
        description: suggestion.description,
        tg: suggestion.tg,
        fabric: suggestion.fabric,
        colour: suggestion.colour,
        materiale: suggestion.materiale
      }
    }
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
      { id: item.id, gencode: item.gencode, itemcode: item.itemcode, fabricode: item.fabricode, varcode: item.varcode, description: item.description, label: "#{item.itemcode}#{item.fabricode}#{item.varcode}", collection: item.collection&.description, collection_id: item.collection_id, tg: item.tg, fabric: item.fabric, colour: item.colour, materiale: item.materiale }
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
        format.html { redirect_to safe_return_to_path(mainware_index_path(q: params[:q], collection_id: params[:collection_id])), notice: "Item was successfully updated." }
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
      format.html { redirect_to safe_return_to_path(mainware_index_path(q: params[:q], collection_id: params[:collection_id])), notice: "Item was successfully destroyed." }
      format.turbo_stream { redirect_to safe_return_to_path(mainware_index_path(q: params[:q], collection_id: params[:collection_id])), notice: "Item was successfully destroyed." }
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
