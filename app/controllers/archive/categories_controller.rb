module Archive
  class CategoriesController < ApplicationController
    before_action -> { require_ability!("manage_archive") }

    def index
      @categories = Archive::Category.order(:name)
      @new_category = Archive::Category.new
    end

    def create
      @category = Archive::Category.new(category_params)
      dest = params[:return_to].presence || archive_categories_path
      if @category.save
        redirect_to dest, notice: "Categoria creata"
      else
        redirect_to dest, alert: @category.errors.full_messages.join(", ")
      end
    end

    def update
      @category = Archive::Category.find(params[:id])
      if @category.update(category_params)
        redirect_to archive_categories_path, notice: "Categoria aggiornata"
      else
        redirect_to archive_categories_path, alert: @category.errors.full_messages.join(", ")
      end
    end

    def destroy
      @category = Archive::Category.find(params[:id])
      if @category.items.any?
        redirect_to archive_categories_path, alert: "Impossibile eliminare: ci sono articoli in questa categoria"
      else
        @category.destroy!
        redirect_to archive_categories_path, notice: "Categoria eliminata"
      end
    end

    private

    def category_params
      params.require(:archive_category).permit(:name)
    end
  end
end
