module Archive
  class ItemsController < ApplicationController
    include Pagy::Backend
    before_action -> { require_ability!("manage_archive") }

    def index
      @categories = Archive::Category.order(:name)
      @locations = Archive::Location.where(enabled: true).order(:code)
      @items = Archive::Item.includes(:category, :location)
                            .search(params[:q])
                            .by_category(params[:category_id])
                            .by_location(params[:location_id])
                            .by_status(params[:status])
                            .order(created_at: :desc)
      @pagy, @items = pagy(@items, items: 50)

      @new_item = Archive::Item.new
    end

    def create
      @item = Archive::Item.new(item_params.except(:pictures))

      if @item.save
        if params[:archive_item][:pictures].present?
          Array(params[:archive_item][:pictures]).reject(&:blank?).each { |pic| @item.pictures.attach(pic) }
        end
        redirect_to archive_items_path, notice: "Articolo creato"
      else
        redirect_to archive_items_path, alert: @item.errors.full_messages.join(", ")
      end
    end

    def show
      @item = Archive::Item.includes(:transactions).find(params[:id])
    end

    def edit
      @item = Archive::Item.find(params[:id])
    end

    def update
      @item = Archive::Item.find(params[:id])
      if params[:archive_item][:pictures].present?
        kept_signed = Array(params[:archive_item][:pictures]).select { |p| p.is_a?(String) && p.present? }
        new_files   = Array(params[:archive_item][:pictures]).select { |p| p.respond_to?(:original_filename) }
        @item.pictures.each { |pic| pic.purge unless kept_signed.include?(pic.signed_id) }
        @item.pictures.attach(new_files) if new_files.any?
      end
      if @item.update(item_params.except(:pictures))
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.refresh }
          format.html { redirect_to archive_items_path, notice: "Articolo aggiornato" }
        end
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def duplicate
      @original = Archive::Item.find(params[:id])
      @item = Archive::Item.new(
        name: @original.name,
        description: @original.description,
        archive_category_id: @original.archive_category_id,
        archive_location_id: @original.archive_location_id,
        notes: @original.notes
      )
      if @item.save
        @original.pictures.each { |pic| @item.pictures.attach(pic.blob) } if @original.pictures.attached?
        redirect_to archive_items_path, notice: "Articolo duplicato (#{@item.code})"
      else
        redirect_to archive_items_path, alert: "Errore duplicazione: #{@item.errors.full_messages.join(", ")}"
      end
    end

    def destroy
      @item = Archive::Item.find(params[:id])
      @item.destroy!
      redirect_to archive_items_path, notice: "Articolo eliminato"
    end

    def checkout
      @item = Archive::Item.find(params[:id])
      @item.transactions.create!(
        action: "checkout",
        date: Time.current,
        operator: current_user,
        out_to: params[:out_to],
        notes: params[:notes]
      )
      @item.update!(status: "out")
      redirect_to archive_items_path, notice: "Articolo preso in carico da #{params[:out_to]}"
    end

    def checkin
      @item = Archive::Item.find(params[:id])
      @item.transactions.create!(
        action: "checkin",
        date: Time.current,
        operator: current_user,
        notes: params[:notes]
      )
      @item.update!(status: "in")
      redirect_to archive_items_path, notice: "Articolo rientrato"
    end

    def qrcodes
      @items = Archive::Item.where(id: params[:ids] || session[:archive_qr_ids]).includes(:category, :location)
      render pdf: "archivio_qr_codici",
             orientation: "portrait",
             page_size: "A4",
             margin: { top: 10, bottom: 10, left: 10, right: 10 }
    end

    def warehouse_search
      q = "%#{params[:q]}%"
      items = Item.where(
        "gencode LIKE :q OR itemcode LIKE :q OR fabricode LIKE :q OR varcode LIKE :q OR description LIKE :q",
        q: q
      ).select(:id, :gencode, :itemcode, :fabricode, :varcode, :description, :collection_id).limit(20)

      gencodes = items.map(&:gencode).compact
      stock = StockLevel.where(gencode: gencodes).positive.group(:gencode)
        .select(:gencode, Arel.sql("SUM(current_qty) AS total_qty"))
        .index_by(&:gencode)

      render json: items.map { |item|
        {
          id: item.id,
          gencode: item.gencode,
          itemcode: item.itemcode,
          fabricode: item.fabricode,
          varcode: item.varcode,
          description: item.description,
          label: "#{item.itemcode}#{item.fabricode}#{item.varcode}",
          collection_id: item.collection_id,
          stock_available: stock[item.gencode]&.total_qty || 0
        }
      }
    end

    private

    def item_params
      params.require(:archive_item).permit(:name, :description, :archive_category_id, :archive_location_id, :notes, :status, pictures: [])
    end
  end
end
