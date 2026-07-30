module Archive
  class ItemTypesController < ApplicationController
    before_action -> { require_ability!("manage_archive") }

    def create
      @item_type = Archive::ItemType.new(item_type_params)
      if @item_type.save
        redirect_to (params[:return_to].presence || archive_items_path), notice: "Tipologia creata"
      else
        redirect_to (params[:return_to].presence || archive_items_path), alert: @item_type.errors.full_messages.join(", ")
      end
    end

    private

    def item_type_params
      params.require(:archive_item_type).permit(:name)
    end
  end
end
