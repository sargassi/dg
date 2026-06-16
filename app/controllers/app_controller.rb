class AppController < ApplicationController
  include Pagy::Backend
  before_action -> { require_ability!('manage_app_sectors') }, except: [:sez, :check_single_qr]
  before_action -> { require_ability!('checkpoint_scan') }, only: [:sez, :check_single_qr]

  ALLOWED_SECTORS = ['f1', 'f2', 'f3', 'f4', 'f5'].freeze
  before_action :set_app_menu, except: [:sez, :check_single_qr]


  def dashboard
    @app_menu = [
      { label: 'Home', path: app_dashboard_path, icon: 'home', active: true, can: 'manage_app_sectors' },
      { label: 'Articoli', path: app_dashboard_articoli_path, icon: 'inventory_2', active: false, can: 'manage_app_sectors' },
      { label: 'Magazzino', path: app_dashboard_magazzino_path, icon: 'warehouse', active: false, can: 'manage_app_sectors' },
      { label: 'Produzione', path: app_dashboard_produzione_path, icon: 'precision_manufacturing', active: false, can: 'manage_app_sectors' },
    ]
  end

  def dashboard_articoli
  end

  def dashboard_magazzino
  end

  def dashboard_produzione
  end

  def inserimento
    if request.post?
      @item = Item.new(inserimento_params)
      if @item.save
        redirect_to app_confirm_ins_path(item_id: @item.id)
      else
        @collections = Collection.all
        render :inserimento, status: :unprocessable_entity
      end
    else
      @item = Item.new
      @collections = Collection.all
    end
  end

  def confirm_ins
    @item = Item.includes(:collection).find(params[:item_id])
  end

  def sez
    @sections = ALLOWED_SECTORS
    @sez = params[:place]
    @q = Prow.ransack(params[:q])
  end

  def check_single_qr
    @sez = params[:place]&.downcase
    unless ALLOWED_SECTORS.include?(@sez)
      redirect_to app_sez_path, alert: "Settore non valido" and return
    end

    @q = Tempesta.where("#{@sez} is null and qrcode = ?", params[:q][:qr_eq]).ransack(params[:q])
    @rows = @q.result(distinct: true)
  end

  def in_warehouse
    if request.post?
      p = in_warehouse_params
      @itemin = Itemin.new(indate: p[:indate], notes: p[:notes], operator_id: p[:operator_id])
      default_collection_id = params[:default_collection_id]
      default_warehouse_id = params[:default_warehouse_id]
      default_location_id = params[:default_location_id]
      details = (p[:itemins_details_attributes]&.values || [])
        .reject { |d| d[:_destroy] == "1" }
        .reject { |d| d[:itemcode].blank? && d[:item_id].blank? }
        .map { |d|
          d = d.except(:_destroy)
          d[:collection_id] = default_collection_id if d[:collection_id].blank? && default_collection_id.present?
          d[:warehouse_id] = default_warehouse_id if d[:warehouse_id].blank? && default_warehouse_id.present?
          d[:location_id] = default_location_id if d[:location_id].blank? && default_location_id.present?
          d
        }
      @itemin.itemins_details.build(details)

      if @itemin.save
        CreateInventoriesFromItemin.new.call(@itemin)
        redirect_to app_in_warehouse_confirmation_path(itemin_id: @itemin.id)
      else
        @default_collection_id = params[:default_collection_id]
        @default_warehouse_id = params[:default_warehouse_id]
        @default_location_id = params[:default_location_id]
        load_form_data
        flash.now[:alert] = @itemin.errors.full_messages.to_sentence
        render :in_warehouse, status: :unprocessable_entity
      end
    else
      @itemin = Itemin.new(indate: Date.current)
      @default_collection_id = @default_warehouse_id = @default_location_id = nil
      load_form_data
    end
  end

  def in_warehouse_confirmation
    @itemin = Itemin.includes(itemins_details: [:warehouse, :location, :item]).find(params[:itemin_id])
  end

  def out_warehouse
    if request.post?
      p = out_warehouse_params
      @itemout = Itemout.new(indate: p[:indate], notes: p[:notes], operator_id: p[:operator_id])
      default_collection_id = params[:default_collection_id]
      default_warehouse_id = params[:default_warehouse_id]
      default_location_id = params[:default_location_id]
      details = (p[:itemouts_details_attributes]&.values || [])
        .reject { |d| d[:_destroy] == "1" }
        .reject { |d| d[:itemcode].blank? && d[:item_id].blank? }
        .map { |d|
          d = d.except(:_destroy)
          d[:collection_id] = default_collection_id if d[:collection_id].blank? && default_collection_id.present?
          d[:warehouse_id] = default_warehouse_id if d[:warehouse_id].blank? && default_warehouse_id.present?
          d[:location_id] = default_location_id if d[:location_id].blank? && default_location_id.present?
          d
        }
      @itemout.itemouts_details.build(details)

      if @itemout.save
        CreateInventoriesFromItemout.new.call(@itemout)
        redirect_to app_out_warehouse_confirmation_path(itemout_id: @itemout.id)
      else
        @default_collection_id = params[:default_collection_id]
        @default_warehouse_id = params[:default_warehouse_id]
        @default_location_id = params[:default_location_id]
        load_form_data
        flash.now[:alert] = @itemout.errors.full_messages.to_sentence
        render :out_warehouse, status: :unprocessable_entity
      end
    else
      @itemout = Itemout.new(indate: Date.current)
      @default_collection_id = @default_warehouse_id = @default_location_id = nil
      load_form_data
    end
  end

  def out_warehouse_confirmation
    @itemout = Itemout.includes(itemouts_details: [:warehouse, :location, :item]).find(params[:itemout_id])
  end

  def move_products
    if request.post?
      p = move_products_params
      @created_ids = []
      errors = []

      details = (p[:itemmovements_details_attributes]&.values || [])
        .reject { |d| d[:_destroy] == "1" }
        .reject { |d| d[:itemcode].blank? && d[:item_id].blank? }
        .reject { |d| d[:warehouse_id].blank? }
        .map { |d| d.except(:_destroy) }

      if params[:dest_warehouse_id].blank?
        @movement = Itemmovement.new(indate: p[:indate])
        load_form_data(ordered: true)
        flash.now[:alert] = "Seleziona un magazzino di destinazione."
        render :move_products, status: :unprocessable_entity and return
      end

      if details.empty?
        @movement = Itemmovement.new(indate: p[:indate])
        load_form_data(ordered: true)
        flash.now[:alert] = "Nessun articolo valido. Compila il codice articolo selezionando dall'autocomplete."
        render :move_products, status: :unprocessable_entity and return
      end

      grouped = details.group_by { |d| [d[:warehouse_id], d[:location_id]] }

      Itemmovement.transaction do
        grouped.each do |(wh_id, loc_id), group_details|
          movement = Itemmovement.new(
            indate: p[:indate], notes: p[:notes], operator_id: p[:operator_id],
            source_warehouse_id: wh_id, source_location_id: loc_id,
            dest_warehouse_id: params[:dest_warehouse_id],
            dest_location_id: params[:dest_location_id]
          )
          movement.itemmovements_details.build(group_details)
          movement.save!
          CreateInventoriesFromItemmovement.new.call(movement)
          @created_ids << movement.id
        end
      end

      redirect_to app_move_products_confirmation_path(ids: @created_ids.join(","))
    else
      @movement = Itemmovement.new(indate: Date.current)
      @default_dest_warehouse_id = @default_dest_location_id = nil
      load_form_data(ordered: true)
    end
  rescue ActiveRecord::RecordInvalid => e
    @movement = Itemmovement.new(indate: p[:indate], dest_warehouse_id: params[:dest_warehouse_id], dest_location_id: params[:dest_location_id])
    @default_dest_warehouse_id = params[:dest_warehouse_id]
    @default_dest_location_id = params[:dest_location_id]
    load_form_data(ordered: true)
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :move_products, status: :unprocessable_entity
  end

  def move_products_confirmation
    ids = params[:ids].to_s.split(",")
    @movements = Itemmovement.includes(:source_warehouse, :dest_warehouse, :source_location, :dest_location, itemmovements_details: :item).where(id: ids).order(:id)
  end

  def itemins_list
    @itemins = Itemin.includes(:operator, itemins_details: [:warehouse, :location, :item])
      .order(indate: :desc)
    @operators = User.joins(:itemins).distinct.order(:name)
    @warehouses = Warehouse.order(:code)
    @locations = Location.order(:code)

    if params[:q].present?
      q = "%#{params[:q]}%"
      @itemins = @itemins.left_joins(itemins_details: :item)
        .where("items.itemcode LIKE :q OR itemins_details.itemcode LIKE :q", q: q)
        .distinct
    end

    if params[:date].present?
      @itemins = @itemins.where(indate: Date.parse(params[:date])) rescue nil
    end

    if params[:operator_id].present?
      @itemins = @itemins.where(operator_id: params[:operator_id])
    end

    if params[:warehouse_id].present?
      @itemins = @itemins.joins(:itemins_details)
        .where(itemins_details: { warehouse_id: params[:warehouse_id] })
        .distinct
    end

    if params[:location_id].present?
      @itemins = @itemins.joins(:itemins_details)
        .where(itemins_details: { location_id: params[:location_id] })
        .distinct
    end

    @pagy, @itemins = pagy(@itemins)
  end

  def itemouts_list
    @itemouts = Itemout.includes(:operator, itemouts_details: [:warehouse, :location, :item])
      .order(indate: :desc)
    @operators = User.joins(:itemouts).distinct.order(:name)
    @warehouses = Warehouse.order(:code)
    @locations = Location.order(:code)

    if params[:q].present?
      q = "%#{params[:q]}%"
      @itemouts = @itemouts.left_joins(itemouts_details: :item)
        .where("items.itemcode LIKE :q OR itemouts_details.itemcode LIKE :q", q: q)
        .distinct
    end

    if params[:date].present?
      @itemouts = @itemouts.where(indate: Date.parse(params[:date])) rescue nil
    end

    if params[:operator_id].present?
      @itemouts = @itemouts.where(operator_id: params[:operator_id])
    end

    if params[:warehouse_id].present?
      @itemouts = @itemouts.joins(:itemouts_details)
        .where(itemouts_details: { warehouse_id: params[:warehouse_id] })
        .distinct
    end

    if params[:location_id].present?
      @itemouts = @itemouts.joins(:itemouts_details)
        .where(itemouts_details: { location_id: params[:location_id] })
        .distinct
    end

    @pagy, @itemouts = pagy(@itemouts)
  end

  def itemmovements_list
    @itemmovements = Itemmovement.includes(:operator, :source_warehouse, :dest_warehouse, :source_location, :dest_location, itemmovements_details: :item)
      .order(indate: :desc)
    @operators = User.joins(:itemmovements).distinct.order(:name)
    @warehouses = Warehouse.order(:code)
    @locations = Location.order(:code)

    if params[:q].present?
      q = "%#{params[:q]}%"
      @itemmovements = @itemmovements.left_joins(itemmovements_details: :item)
        .where("items.itemcode LIKE :q OR itemmovements_details.itemcode LIKE :q", q: q)
        .distinct
    end

    if params[:date].present?
      @itemmovements = @itemmovements.where(indate: Date.parse(params[:date])) rescue nil
    end

    if params[:operator_id].present?
      @itemmovements = @itemmovements.where(operator_id: params[:operator_id])
    end

    if params[:warehouse_id].present?
      wh_id = params[:warehouse_id]
      @itemmovements = @itemmovements.where("source_warehouse_id = ? OR dest_warehouse_id = ?", wh_id, wh_id)
    end

    if params[:location_id].present?
      loc_id = params[:location_id]
      @itemmovements = @itemmovements.where("source_location_id = ? OR dest_location_id = ?", loc_id, loc_id)
    end

    @pagy, @itemmovements = pagy(@itemmovements)
  end

  private

  def set_app_menu
    active = action_name
    @app_menu = [
      { label: 'Home', path: app_dashboard_path, icon: 'home', active: active == 'dashboard', can: 'manage_app_sectors' },
      { label: 'Articoli', path: app_dashboard_articoli_path, icon: 'inventory_2', active: active == 'dashboard_articoli', can: 'manage_app_sectors' },
      { label: 'Magazzino', path: app_dashboard_magazzino_path, icon: 'warehouse', active: active == 'dashboard_magazzino', can: 'manage_app_sectors' },
      { label: 'Produzione', path: app_dashboard_produzione_path, icon: 'precision_manufacturing', active: active == 'dashboard_produzione', can: 'manage_app_sectors' },
      { label: 'Inserimento', path: app_inserimento_path, icon: 'add_box', active: active == 'inserimento', can: 'manage_app_sectors' },
      { label: 'IN', path: app_in_warehouse_path, icon: 'download', active: %w[in_warehouse in_warehouse_confirmation].include?(active), can: 'manage_app_sectors' },
      { label: 'OUT', path: app_out_warehouse_path, icon: 'upload', active: %w[out_warehouse out_warehouse_confirmation].include?(active), can: 'manage_app_sectors' },
      { label: 'VAR', path: app_move_products_path, icon: 'swap_horiz', active: %w[move_products move_products_confirmation].include?(active), can: 'manage_app_sectors' },
      { label: 'Carichi', path: app_itemins_list_path, icon: 'list_alt', active: active == 'itemins_list', can: 'manage_app_sectors' },
      { label: 'Scarichi', path: app_itemouts_list_path, icon: 'list_alt', active: active == 'itemouts_list', can: 'manage_app_sectors' },
      { label: 'Variazioni', path: app_itemmovements_list_path, icon: 'swap_vert', active: active == 'itemmovements_list', can: 'manage_app_sectors' },
    ]
  end

  def load_form_data(ordered: false)
    @collections = Collection.all
    @warehouses = ordered ? Warehouse.order(:code) : Warehouse.all
    @locations = ordered ? Location.order(:code) : Location.all
  end

  def in_warehouse_params
    params.require(:itemin).permit(:indate, :notes, :operator_id,
      itemins_details_attributes: [:id, :itemcode, :qty, :item_id, :collection_id, :warehouse_id, :location_id, :operationtype_id, :_destroy])
  end

  def out_warehouse_params
    params.require(:itemout).permit(:indate, :notes, :operator_id,
      itemouts_details_attributes: [:id, :itemcode, :qty, :item_id, :collection_id, :warehouse_id, :location_id, :operationtype_id, :_destroy])
  end

  def move_products_params
    params.require(:itemmovement).permit(:indate, :notes, :operator_id,
      itemmovements_details_attributes: [:id, :itemcode, :qty, :item_id, :collection_id, :warehouse_id, :location_id, :operationtype_id, :_destroy])
  end

  def inserimento_params
    params.require(:item).permit(:itemcode, :fabricode, :varcode, :description, :tg, :note, :fabric, :colour, :materiale, :collection_id, pictures: [])
  end

end
