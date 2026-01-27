class EtigensController < ApplicationController
  before_action :set_etigen, only: %i[ show edit update destroy ]

  # GET /etigens or /etigens.json
  def index
    @etigens = Etigen.all
  end

  # GET /etigens/1 or /etigens/1.json
  def show
  end

  # GET /etigens/new
  def new
    @etigen = Etigen.new
  end

  # GET /etigens/1/edit
  def edit
  end

  # POST /etigens or /etigens.json
  def create
    @etigen = Etigen.new(etigen_params)

    respond_to do |format|
      if @etigen.save
        format.html { redirect_to etigen_url(@etigen), notice: "Creata." }
        format.json { render :show, status: :created, location: @etigen }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @etigen.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /etigens/1 or /etigens/1.json
  def update

    respond_to do |format|
      if @etigen.update(etigen_params)
        src = params[:src]

        if src.present? and (src == 'qty' || src == 'num' )
          format.html { redirect_to utilities_etichette_gen_path, notice: "Aggiornata." }
          format.json { render :show, status: :ok, location: @etigen }
        else
          format.html { redirect_to etigen_url(@etigen), notice: "Aggiornata." }
          format.json { render :show, status: :ok, location: @etigen }
        end
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @etigen.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /etigens/1 or /etigens/1.json
  def destroy
    @etigen.destroy

    respond_to do |format|
      format.html { redirect_to etigens_url, notice: "Etigen was successfully destroyed." }
      format.json { head :no_content }
    end
  end


  def etichette
    @products = Etigen.all.order('created_at DESC').group_by{|product| product.group}
    #@products = Product.all.group_by{|product| product.created_at.to_s}
    respond_to do |format|

    format.pdf do
      render :pdf => @products.count.to_s , orientation: "portrait",page_size: 'A4',margin:  {top:'0mm',bottom: '0m',left: '0mm',right:'0mm' }, disable_smart_shrinking: true, show_as_html: params.key?('debug')

    end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_etigen
      @etigen = Etigen.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def etigen_params
      params.require(:etigen).permit(:riga1, :riga2, :riga3, :riga4, :riga5, :qty, :status, :group, :dategroup, :pages)
    end
end
