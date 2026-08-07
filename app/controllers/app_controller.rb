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
    set_return_to(inventories_dashboard_path)

    if request.post?
      result = MovementCreationService.new(
        Itemin, params[:itemin],
        defaults: {
          collection_id: params[:default_collection_id],
          warehouse_id: params[:default_warehouse_id],
          location_id: params[:default_location_id]
        }
      ).call
      @itemin = result.movement

      if result.success
        redirect_to @return_to, notice: "Carico creato con successo."
      else
        @from_seleziona = params[:return_to].to_s.include?(inventories_seleziona_path)
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
      @from_seleziona = @return_to.to_s.include?(inventories_seleziona_path)

      if session[:carico_prefill].present?
        @from_seleziona = true
        prefill = session.delete(:carico_prefill)
        details = prefill.map { |s|
          item = Item.find_by(id: s["item_id"])
          {
            itemcode: item&.itemcode || s["gencode"],
            item_id: s["item_id"],
            collection_id: s["collection_id"],
            qty: (s["qty"] || 1).to_i,
            operationtype_id: 1
          }
        }
        @itemin.itemins_details.build(details)
        @default_collection_id = details.first["collection_id"]
      end

      load_form_data
    end
  end

  def in_warehouse_confirmation
    @itemin = Itemin.includes(itemins_details: [:warehouse, :location, :item]).find(params[:itemin_id])
    @return_to = safe_return_to(params[:return_to]) || inventories_dashboard_path
  end

  def out_warehouse
    set_return_to(inventories_dashboard_path)

    if request.post?
      result = MovementCreationService.new(
        Itemout, params[:itemout],
        defaults: {
          collection_id: params[:default_collection_id],
          warehouse_id: params[:default_warehouse_id],
          location_id: params[:default_location_id]
        }
      ).call
      @itemout = result.movement

      if result.success
        redirect_to @return_to, notice: "Scarico creato con successo."
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
    @return_to = safe_return_to(params[:return_to]) || inventories_dashboard_path
  end

  def move_products
    set_return_to(inventories_dashboard_path)

    if request.post?
      p = move_products_params
      @created_ids = []

      details = MovementBuilder.filter_details(Itemmovement, p, defaults: {
          warehouse_id: params[:source_warehouse_id],
          location_id: params[:source_location_id]
        }).reject { |d| d[:warehouse_id].blank? }

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

      item_ids = details.map { |d| d[:item_id] }.compact.uniq
      items = Item.where(id: item_ids).index_by(&:id)
      gencodes = items.values.map(&:gencode).compact.uniq
      stock = StockLevel.where(gencode: gencodes)
        .each_with_object({}) { |sl, h| h[[sl.gencode, sl.warehouse_id, sl.location_id.to_i]] = sl.current_qty }

      details.each do |d|
        next unless d[:item_id]
        item = items[d[:item_id].to_i]
        next unless item

        available = stock[[item.gencode, d[:warehouse_id].to_i, d[:location_id].to_i]] || 0
        if d[:qty].to_i > available
          @movement = Itemmovement.new(indate: p[:indate])
          load_form_data(ordered: true)
          flash.now[:alert] = "#{item.gencode}: quantità #{d[:qty]} supera la disponibilità (#{available} pz)"
          render :move_products, status: :unprocessable_entity and return
        end
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
          InventoryCreator.new.call(movement)
          @created_ids << movement.id
        end
      end

      redirect_to @return_to, notice: "Spostamento creato con successo."
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

  def mobile_in
    set_return_to(app_dashboard_path)

    if request.post?
      result = MovementCreationService.new(
        Itemin, params[:itemin],
        defaults: {
          collection_id: params[:default_collection_id],
          warehouse_id: params[:default_warehouse_id],
          location_id: params[:default_location_id]
        }
      ).call
      @itemin = result.movement

      if result.success
        redirect_to app_mobile_in_confirmation_path(itemin_id: @itemin.id), notice: "Carico creato con successo."
      else
        @default_collection_id = params[:default_collection_id]
        @default_warehouse_id = params[:default_warehouse_id]
        @default_location_id = params[:default_location_id]
        load_form_data
        flash.now[:alert] = @itemin.errors.full_messages.to_sentence
        render :mobile_in, status: :unprocessable_entity
      end
    else
      @itemin = Itemin.new(indate: Date.current)
      @default_collection_id = @default_warehouse_id = @default_location_id = nil
      load_form_data
    end
  end

  def mobile_in_confirmation
    @itemin = Itemin.includes(itemins_details: [:warehouse, :location, :item]).find(params[:itemin_id])
  end

  def mobile_out
    set_return_to(app_dashboard_path)

    if request.post?
      p = params[:itemout]
      details = MovementBuilder.filter_details(Itemout, p, defaults: {
          collection_id: params[:default_collection_id],
          warehouse_id: params[:default_warehouse_id],
          location_id: params[:default_location_id]
        }).reject { |d| d[:warehouse_id].blank? }

      item_ids = details.map { |d| d[:item_id] }.compact.uniq
      items = Item.where(id: item_ids).index_by(&:id)
      gencodes = items.values.map(&:gencode).compact.uniq
      item_ids = details.map { |d| d[:item_id] }.compact.uniq
      items = Item.where(id: item_ids).index_by(&:id)
      gencodes = items.values.map(&:gencode).compact.uniq
      stock = StockLevel.where(gencode: gencodes)
        .each_with_object({}) { |sl, h| h[[sl.gencode, sl.warehouse_id, sl.location_id.to_i]] = sl.current_qty }

      details.each do |d|
        next unless d[:item_id]
        item = items[d[:item_id].to_i]
        next unless item

        available = stock[[item.gencode, d[:warehouse_id].to_i, d[:location_id].to_i]] || 0
        if d[:qty].to_i > available
          @itemout = Itemout.new(indate: p[:indate])
          @default_collection_id = params[:default_collection_id]
          @default_warehouse_id = params[:default_warehouse_id]
          @default_location_id = params[:default_location_id]
          load_form_data
          flash.now[:alert] = "#{item.gencode}: quantità #{d[:qty]} supera la disponibilità (#{available} pz)"
          render :mobile_out, status: :unprocessable_entity and return
        end
      end

      result = MovementCreationService.new(
        Itemout, params[:itemout],
        defaults: {
          collection_id: params[:default_collection_id],
          warehouse_id: params[:default_warehouse_id],
          location_id: params[:default_location_id]
        }
      ).call
      @itemout = result.movement

      if result.success
        redirect_to app_mobile_out_confirmation_path(itemout_id: @itemout.id), notice: "Scarico creato con successo."
      else
        @default_collection_id = params[:default_collection_id]
        @default_warehouse_id = params[:default_warehouse_id]
        @default_location_id = params[:default_location_id]
        load_form_data
        flash.now[:alert] = @itemout.errors.full_messages.to_sentence.presence || result.error
        render :mobile_out, status: :unprocessable_entity
      end
    else
      @itemout = Itemout.new(indate: Date.current)
      @default_collection_id = @default_warehouse_id = @default_location_id = nil
      load_form_data
    end
  end

  def mobile_out_confirmation
    @itemout = Itemout.includes(itemouts_details: [:warehouse, :location, :item]).find(params[:itemout_id])
  end

  def mobile_var
    set_return_to(app_dashboard_path)

    if request.post?
      p = move_products_params
      details = MovementBuilder.filter_details(Itemmovement, p, defaults: {
          warehouse_id: params[:source_warehouse_id],
          location_id: params[:source_location_id]
        }).reject { |d| d[:warehouse_id].blank? }

      if params[:dest_warehouse_id].blank?
        @movement = Itemmovement.new(indate: p[:indate])
        load_form_data(ordered: true)
        flash.now[:alert] = "Seleziona un magazzino di destinazione."
        render :mobile_var, status: :unprocessable_entity and return
      end

      if details.empty?
        @movement = Itemmovement.new(indate: p[:indate])
        load_form_data(ordered: true)
        flash.now[:alert] = "Nessun articolo valido. Compila il codice articolo selezionando dall'autocomplete."
        render :mobile_var, status: :unprocessable_entity and return
      end

      item_ids = details.map { |d| d[:item_id] }.compact.uniq
      items = Item.where(id: item_ids).index_by(&:id)
      gencodes = items.values.map(&:gencode).compact.uniq
      stock = StockLevel.where(gencode: gencodes)
        .each_with_object({}) { |sl, h| h[[sl.gencode, sl.warehouse_id, sl.location_id.to_i]] = sl.current_qty }

      details.each do |d|
        next unless d[:item_id]
        item = items[d[:item_id].to_i]
        next unless item

        available = stock[[item.gencode, d[:warehouse_id].to_i, d[:location_id].to_i]] || 0
        if d[:qty].to_i > available
          @movement = Itemmovement.new(indate: p[:indate])
          load_form_data(ordered: true)
          flash.now[:alert] = "#{item.gencode}: quantità #{d[:qty]} supera la disponibilità (#{available} pz)"
          render :mobile_var, status: :unprocessable_entity and return
        end
      end

      grouped = details.group_by { |d| [d[:warehouse_id], d[:location_id]] }

      @created_ids = []
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
          InventoryCreator.new.call(movement)
          @created_ids << movement.id
        end
      end

      redirect_to app_mobile_var_confirmation_path(ids: @created_ids.join(",")), notice: "Spostamento creato con successo."
    else
      @movement = Itemmovement.new(indate: Date.current)
      @default_dest_warehouse_id = @default_dest_location_id = nil
      load_form_data(ordered: true)
    end
  rescue ActiveRecord::RecordInvalid => e
    @movement = Itemmovement.new(indate: params[:itemmovement][:indate], dest_warehouse_id: params[:dest_warehouse_id], dest_location_id: params[:dest_location_id])
    @default_dest_warehouse_id = params[:dest_warehouse_id]
    @default_dest_location_id = params[:dest_location_id]
    load_form_data(ordered: true)
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :mobile_var, status: :unprocessable_entity
  end

  def mobile_var_confirmation
    ids = params[:ids].to_s.split(",")
    @movements = Itemmovement.includes(:source_warehouse, :dest_warehouse, :source_location, :dest_location, itemmovements_details: :item).where(id: ids).order(:id)
  end

  def mobile_reassign
    if request.post?
      rows = Array(params[:reassign]).select { |r| r[:item_id].to_s.present? }

      if params[:source_warehouse_id].blank?
        load_form_data(ordered: true)
        flash.now[:alert] = "Seleziona un magazzino di origine."
        render :mobile_reassign, status: :unprocessable_entity and return
      end

      if params[:dest_warehouse_id].blank?
        load_form_data(ordered: true)
        flash.now[:alert] = "Seleziona un magazzino di destinazione."
        render :mobile_reassign, status: :unprocessable_entity and return
      end

      if rows.empty?
        load_form_data(ordered: true)
        flash.now[:alert] = "Nessun articolo valido. Seleziona almeno un articolo dall'autocomplete."
        render :mobile_reassign, status: :unprocessable_entity and return
      end

      item_ids = rows.map { |r| r[:item_id] }.compact.uniq
      gencodes = Item.where(id: item_ids).pluck(:gencode).compact.uniq

      result = ReassignStockService.call(
        gencodes: gencodes,
        src_warehouse_id: params[:source_warehouse_id],
        src_location_id: params[:source_location_id],
        dst_warehouse_id: params[:dest_warehouse_id],
        dst_location_id: params[:dest_location_id]
      )

      if result.success
        session[:mobile_reassign_result] = result.stats
        redirect_to app_mobile_reassign_confirm_path, notice: "Riallocazione completata con successo."
      else
        load_form_data(ordered: true)
        flash.now[:alert] = result.error
        render :mobile_reassign, status: :unprocessable_entity
      end
    else
      @default_dest_warehouse_id = @default_dest_location_id = nil
      load_form_data(ordered: true)
    end
  end

  def mobile_reassign_confirm
    @stats = session.delete(:mobile_reassign_result)
    redirect_to app_mobile_reassign_path, alert: "Nessuna riallocazione effettuata." if @stats.blank?
  end

  def mobile_print
    if request.post?
      rows = Array(params[:print]).select { |r| r[:item_id].to_s.present? }

      if rows.empty?
        load_form_data(ordered: true)
        flash.now[:alert] = "Nessun articolo valido. Seleziona almeno un articolo dall'autocomplete."
        render :mobile_print, status: :unprocessable_entity and return
      end

      session[:mobile_print_items] = rows.map do |r|
        {
          "item_id" => r[:item_id].to_i,
          "qty" => r[:qty].to_i.positive? ? r[:qty].to_i : 1,
          "warehouse_id" => r[:warehouse_id],
          "location_id" => r[:location_id]
        }
      end

      redirect_to app_mobile_print_confirmation_path
    else
      load_form_data(ordered: true)
    end
  end

  def mobile_print_confirmation
    @items = load_mobile_print_items
    redirect_to app_mobile_print_path, alert: "Nessun articolo selezionato." if @items.empty?
  end

  def mobile_print_label
    item = Item.find(params[:item_id])
    qty = [params[:qty].to_i, 1].max
    @entries = [{ item: item, qty: qty }]
    render pdf: "mobile_print_label_#{item.gencode}",
           template: "app/mobile_print_label",
           orientation: "portrait",
           page_size: "A4",
           margin: { top: 5, bottom: 5, left: 5, right: 5 },
           disable_smart_shrinking: true,
           show_as_html: params.key?("debug")
  end

  def itemins_list
    redirect_to inventories_movements_path(operationtype_id: 1)
  end

  def itemouts_list
    redirect_to inventories_movements_path(operationtype_id: 2)
  end

  def itemmovements_list
    redirect_to inventories_movements_path(operationtype_id: 3)
  end

  private

  def set_return_to(fallback)
    @return_to = safe_return_to(params[:return_to]) || safe_return_to(request.referer) || fallback
  end

  def safe_return_to(url)
    return nil if url.blank?
    uri = URI.parse(url)
    return nil if uri.host.present? && uri.host != request.host
    return nil if uri.path.blank?
    uri.path
  rescue URI::InvalidURIError
    nil
  end

  def set_app_menu
    active = action_name
    @app_menu = [
      { label: 'Home', path: app_dashboard_path, icon: 'home', active: active == 'dashboard', can: 'manage_app_sectors' },
      { label: 'Articoli', path: app_dashboard_articoli_path, icon: 'inventory_2', active: active == 'dashboard_articoli', can: 'manage_app_sectors' },
      { label: 'Magazzino', path: app_dashboard_magazzino_path, icon: 'warehouse', active: active == 'dashboard_magazzino', can: 'manage_app_sectors' },
      { label: 'Produzione', path: app_dashboard_produzione_path, icon: 'precision_manufacturing', active: active == 'dashboard_produzione', can: 'manage_app_sectors' },
      { label: 'Inserimento', path: app_inserimento_path, icon: 'add_box', active: active == 'inserimento', can: 'manage_app_sectors' },
      { label: 'IN', path: app_mobile_in_path, icon: 'download', active: %w[mobile_in mobile_in_confirmation].include?(active), can: 'manage_app_sectors' },
      { label: 'OUT', path: app_mobile_out_path, icon: 'upload', active: %w[mobile_out mobile_out_confirmation].include?(active), can: 'manage_app_sectors' },
      { label: 'VAR', path: app_mobile_var_path, icon: 'swap_horiz', active: %w[mobile_var mobile_var_confirmation].include?(active), can: 'manage_app_sectors' },
      { label: 'RIALLOCA', path: app_mobile_reassign_path, icon: 'swap_vert', active: %w[mobile_reassign mobile_reassign_confirm].include?(active), can: 'manage_app_sectors' },
      { label: 'QR', path: app_mobile_print_path, icon: 'qr_code', active: %w[mobile_print mobile_print_confirmation].include?(active), can: 'manage_app_sectors' },
      { label: 'Carichi', path: inventories_movements_path(operationtype_id: 1), icon: 'list_alt', active: false, can: 'manage_app_sectors' },
      { label: 'Scarichi', path: inventories_movements_path(operationtype_id: 2), icon: 'list_alt', active: false, can: 'manage_app_sectors' },
      { label: 'Variazioni', path: inventories_movements_path(operationtype_id: 3), icon: 'swap_vert', active: false, can: 'manage_app_sectors' },
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

  def load_mobile_print_items
    return [] if session[:mobile_print_items].blank?

    ids = session[:mobile_print_items].map { |r| r["item_id"] }
    items = Item.where(id: ids).includes(:collection).index_by(&:id)

    session[:mobile_print_items].filter_map do |r|
      item = items[r["item_id"].to_i]
      next unless item
      { item: item, qty: (r["qty"] || 1).to_i, warehouse_id: r["warehouse_id"], location_id: r["location_id"] }
    end
  end

end
