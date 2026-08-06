class IteminsController < ApplicationController
  include MovementWorkflow
  before_action -> { require_ability!('manage_itemins') }
  before_action :set_itemin, only: %i[ show edit update destroy ]

  movement_workflow(
    movement_class:        Itemin,
    movement_var:          :@itemin,
    details_attr_key:      :itemins_details_attributes,
    preview_session_key:   :itemin_preview,
    new_path_helper:       :new_itemin_path,
    preview_path_helper:   :preview_itemins_path,
    success_redirect_path: :inventories_dashboard_path,
    preview_notice_label:  "carico"
  )

  def index
    @itemins = Itemin.all
  end

  def show
  end

  def edit
  end

  def update
    respond_to do |format|
      if @itemin.update(itemin_params)
        format.html { redirect_to itemin_url(@itemin), notice: "Itemin was successfully updated." }
        format.json { render :show, status: :ok, location: @itemin }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @itemin.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @itemin.destroy

    respond_to do |format|
      format.html { redirect_to itemins_url, notice: "Itemin was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  def set_itemin
    @itemin = Itemin.find(params[:id])
  end

  def permitted_params
    params.require(:itemin).permit(:indate, :notes, :operator_id,
      itemins_details_attributes: [:id, :itemcode, :qty, :item_id, :collection_id, :warehouse_id, :location_id, :operationtype_id, :_destroy])
  end

  def itemin_params
    permitted_params
  end
end
