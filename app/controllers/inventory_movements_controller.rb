class InventoryMovementsController < ApplicationController
  include Pagy::Backend
  include InventoriesViews
  before_action -> { require_ability!('manage_inventory') }

  def dashboard
    @latest_itemins = Itemin.includes(:operator, itemins_details: [:warehouse, :location, :item]).order(indate: :desc).limit(10)
    @latest_itemouts = Itemout.includes(:operator, itemouts_details: [:warehouse, :location, :item]).order(indate: :desc).limit(10)
    @latest_itemmovements = Itemmovement.includes(:operator, :source_warehouse, :dest_warehouse, :source_location, :dest_location, itemmovements_details: :item).order(indate: :desc).limit(10)
  end

  def movements
    @operationtypes = Operationtype.all
    @operators = User.where(user_type: "company_operator").order(:name)

    itemins = Itemin.includes(:operator, itemins_details: [:warehouse, :location, :item]).order(indate: :desc)
    itemouts = Itemout.includes(:operator, itemouts_details: [:warehouse, :location, :item]).order(indate: :desc)
    itemmovements = Itemmovement.includes(:operator, :source_warehouse, :dest_warehouse, :source_location, :dest_location, itemmovements_details: :item).order(indate: :desc)

    if params[:operationtype_id].present?
      case params[:operationtype_id]
      when "1" then itemouts = itemouts.none; itemmovements = itemmovements.none
      when "2" then itemins = itemins.none; itemmovements = itemmovements.none
      when "3" then itemins = itemins.none; itemouts = itemouts.none
      end
    end

    if params[:date_from].present?
      date_from = Date.parse(params[:date_from]) rescue nil
      itemins = itemins.where("indate >= ?", date_from) if date_from
      itemouts = itemouts.where("indate >= ?", date_from) if date_from
      itemmovements = itemmovements.where("indate >= ?", date_from) if date_from
    end

    date_to = params[:date_to].present? ? (Date.parse(params[:date_to]) rescue nil) : Date.current
    if date_to
      itemins = itemins.where("indate <= ?", date_to)
      itemouts = itemouts.where("indate <= ?", date_to)
      itemmovements = itemmovements.where("indate <= ?", date_to)
    end

    if params[:operator_id].present?
      itemins = itemins.where(operator_id: params[:operator_id])
      itemouts = itemouts.where(operator_id: params[:operator_id])
      itemmovements = itemmovements.where(operator_id: params[:operator_id])
    end

    if params[:q].present?
      q = "%#{params[:q]}%"
      itemin_ids = IteminsDetail.left_joins(:item)
        .where("items.gencode LIKE :q OR itemins_details.itemcode LIKE :q", q: q).select(:itemin_id)
      itemout_ids = ItemoutsDetail.left_joins(:item)
        .where("items.gencode LIKE :q OR itemouts_details.itemcode LIKE :q", q: q).select(:itemout_id)
      itemmovement_ids = ItemmovementsDetail.left_joins(:item)
        .where("items.gencode LIKE :q OR itemmovements_details.itemcode LIKE :q", q: q).select(:itemmovement_id)
      itemins = itemins.where(id: itemin_ids)
      itemouts = itemouts.where(id: itemout_ids)
      itemmovements = itemmovements.where(id: itemmovement_ids)
    end

    itemins = itemins.load
    itemouts = itemouts.load
    itemmovements = itemmovements.load

    combined = (itemins.map { |m| [m, :itemin] } + itemouts.map { |m| [m, :itemout] } + itemmovements.map { |m| [m, :itemmovement] })
      .sort_by { |m, _| m.indate }.reverse

    @pagy = Pagy.new(count: combined.size, items: 25, page: params[:page] || 1)
    @movements = combined[@pagy.offset, @pagy.items] || []
  end

  def movement_label
    @movement_type = params[:type]
    @items = case @movement_type
    when "itemin"
      Itemin.includes(itemins_details: :item).find(params[:id]).itemins_details
    when "itemout"
      Itemout.includes(itemouts_details: :item).find(params[:id]).itemouts_details
    when "itemmovement"
      Itemmovement.includes(itemmovements_details: :item).find(params[:id]).itemmovements_details
    else
      return redirect_to inventories_movements_path, alert: "Tipo movimento non valido"
    end

    render pdf: "etichette_#{params[:type]}_#{params[:id]}",
           template: "inventories/movement_label",
           orientation: "portrait",
           page_size: "A4",
           margin: { top: "0mm", bottom: "0mm", left: "0mm", right: "0mm" },
           disable_smart_shrinking: true,
           show_as_html: params.key?("debug")
  end

  def movement_modal
    @record = case params[:type]
    when "itemin"
      Itemin.includes(itemins_details: [:warehouse, :location, :operationtype, :item]).find(params[:id])
    when "itemout"
      Itemout.includes(itemouts_details: [:warehouse, :location, :operationtype, :item]).find(params[:id])
    when "itemmovement"
      Itemmovement.includes(itemmovements_details: [:item]).find(params[:id])
    end
    @type = params[:type].to_sym
    render layout: false, template: "inventories/movement_modal"
  end
end
