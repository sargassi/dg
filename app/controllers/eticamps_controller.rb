class EticampsController < ApplicationController
  before_action :set_eticamp, only: %i[ show edit update destroy ]

  # GET /eticamps or /eticamps.json
  def index
    @eticamps = Eticamp.all
  end

  # GET /eticamps/1 or /eticamps/1.json
  def show
  end

  # GET /eticamps/new
  def new
    @eticamp = Eticamp.new
  end

  # GET /eticamps/1/edit
  def edit
  end

  # POST /eticamps or /eticamps.json
  def create
    @eticamp = Eticamp.new(eticamp_params)

    respond_to do |format|
      if @eticamp.save
        format.html { redirect_to eticamp_url(@eticamp), notice: "Eticamp was successfully created." }
        format.json { render :show, status: :created, location: @eticamp }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @eticamp.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /eticamps/1 or /eticamps/1.json
  def update
    respond_to do |format|
      if @eticamp.update(eticamp_params)
        format.html { redirect_to eticamp_url(@eticamp), notice: "Eticamp was successfully updated." }
        format.json { render :show, status: :ok, location: @eticamp }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @eticamp.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /eticamps/1 or /eticamps/1.json
  def destroy
    @eticamp.destroy

    respond_to do |format|
      format.html { redirect_to eticamps_url, notice: "Eticamp was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def etichette
    @etix = Eticamp.all.order('created_at DESC').group_by {|et| et.group }

    respond_to do |format|
      format.html
      format.pdf do
        render pdf: 'Campione_' + @etix.count.to_s, orientation: 'portrait', page_size: 'A4',
               margin: { top: '0mm', bottom: '0m', left: '0mm', right: '0mm' }, disable_smart_shrinking: true, show_as_html: params.key?('debug')
      end
    end

  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_eticamp
      @eticamp = Eticamp.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def eticamp_params
      params.require(:eticamp).permit(:itemcode, :fabricode, :varcode, :season, :group)
    end
end
