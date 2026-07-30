module Archive
  class LocationsController < ApplicationController
    before_action -> { require_ability!("manage_archive") }

    def index
      @locations = Archive::Location.includes(:items).order(:code)
      @new_location = Archive::Location.new
    end

    def create
      @location = Archive::Location.new(location_params)
      dest = params[:return_to].presence || archive_locations_path
      if @location.save
        redirect_to dest, notice: "Ubicazione creata"
      else
        redirect_to dest, alert: @location.errors.full_messages.join(", ")
      end
    end

    def edit
      @location = Archive::Location.find(params[:id])
      @sectors = Archive::Location.sectors.order(:code)
    end

    def update
      @location = Archive::Location.find(params[:id])
      if @location.update(location_params)
        redirect_to archive_locations_path, notice: "Ubicazione aggiornata"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @location = Archive::Location.find(params[:id])
      if @location.items.any?
        redirect_to archive_locations_path, alert: "Impossibile eliminare: ci sono articoli in questa ubicazione"
      else
        @location.destroy!
        redirect_to archive_locations_path, notice: "Ubicazione eliminata"
      end
    end

    def qrcodes
      @locations = Archive::Location.where(id: params[:ids] || Archive::Location.pluck(:id))
      render pdf: "archivio_ubicazioni_qr",
             orientation: "portrait",
             page_size: "A4",
             margin: { top: 10, bottom: 10, left: 10, right: 10 }
    end

    private

    def location_params
      params.require(:archive_location).permit(:code, :description, :enabled, :parent_id)
    end
  end
end
