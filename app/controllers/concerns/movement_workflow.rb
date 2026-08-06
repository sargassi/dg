module MovementWorkflow
  extend ActiveSupport::Concern

  included do
    before_action :load_warehouses_locations_operationtypes, only: %i[ new edit ]
  end

  def new
    if session[preview_session_key].present?
      preview = session[preview_session_key]
      m = movement_class.new(indate: preview["indate"], notes: preview["notes"])
      (preview[details_attr_key.to_s] || {}).values
        .reject { |d| d["_destroy"] == "1" }
        .reject { |d| d["itemcode"].blank? && d["item_id"].blank? }
        .map { |d| d.except("_destroy") }
        .each { |d| m.send(details_attr_key).build(d) }
      instance_variable_set(movement_var, m)
    else
      yield if block_given?
      instance_variable_set(movement_var, movement_class.new(indate: Date.current)) unless movement
    end
    after_new if respond_to?(:after_new, true)
  end

  def create
    m = movement_class.new(indate: permitted_params[:indate], notes: permitted_params[:notes], operator_id: permitted_params[:operator_id])

    details = (permitted_params[details_attr_key]&.values || [])
      .reject { |d| d[:_destroy] == "1" }
      .reject { |d| d[:itemcode].blank? && d[:item_id].blank? }
      .map { |d| d.except(:_destroy) }
    details.each { |d| m.send(details_attr_key).build(d) }

    before_create_validation(m, details) if respond_to?(:before_create_validation, true)

    if m.valid?
      store_preview_params
      instance_variable_set(:@params, permitted_params.to_unsafe_h.with_indifferent_access)
      load_preview_data

      respond_to do |format|
        format.html { redirect_to send(preview_path), notice: "Anteprima #{preview_notice_label} pronta" }
        format.turbo_stream { redirect_to send(preview_path), notice: "Anteprima #{preview_notice_label} pronta" }
      end
    else
      load_warehouses_locations_operationtypes
      flash.now[:alert] = m.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def preview
    @params = session[preview_session_key]&.with_indifferent_access
    return redirect_to send(new_path), alert: "Nessun dato in anteprima" unless @params

    load_preview_data
  end

  def confirm
    @params = session[preview_session_key]&.with_indifferent_access
    return redirect_to send(new_path), alert: "Nessun dato, riprova" unless @params

    result = MovementCreationService.new(movement_class, @params).call
    m = result.movement
    instance_variable_set(movement_var, m)

    if result.success
      session.delete(preview_session_key)
      redirect_to send(success_redirect_path), notice: "Operazione creata con #{m.send(details_attr_key).size} articoli"
    else
      redirect_to send(new_path), alert: "Errore durante il salvataggio: #{result.error || m.errors.full_messages.to_sentence}"
    end
  end

  private

  def movement_class
    self.class.movement_class
  end

  def movement_var
    self.class.movement_var
  end

  def details_attr_key
    self.class.details_attr_key
  end

  def preview_session_key
    self.class.preview_session_key
  end

  def new_path
    self.class.new_path_helper
  end

  def preview_path
    self.class.preview_path_helper
  end

  def success_redirect_path
    self.class.success_redirect_path
  end

  def preview_notice_label
    self.class.preview_notice_label
  end

  def movement
    instance_variable_get(movement_var)
  end

  def store_preview_params
    session[preview_session_key] = permitted_params.to_unsafe_h
  end

  def load_preview_data
    @details = (@params[details_attr_key] || {}).values.reject { |d| d[:_destroy] == "1" }
    warehouse_ids = @details.map { |d| d[:warehouse_id] }.compact.uniq
    location_ids = @details.map { |d| d[:location_id] }.compact.uniq
    operationtype_ids = @details.map { |d| d[:operationtype_id] }.compact.uniq
    @warehouse_idx = Warehouse.where(id: warehouse_ids).index_by { |w| w.id.to_s }
    @location_idx = Location.where(id: location_ids).index_by { |l| l.id.to_s }
    @operationtype_idx = Operationtype.where(id: operationtype_ids).index_by { |o| o.id.to_s }
    @operator = User.find_by(id: @params[:operator_id])
  end

  def load_warehouses_locations_operationtypes
    @warehouses = Warehouse.all
    @locations = Location.all
    @operationtypes = Operationtype.all
  end

  class_methods do
    attr_reader :movement_class, :movement_var, :details_attr_key,
                :preview_session_key,
                :new_path_helper, :preview_path_helper, :success_redirect_path,
                :preview_notice_label

    def movement_workflow(movement_class:, movement_var:, details_attr_key:,
                          preview_session_key:,
                          new_path_helper:, preview_path_helper:,
                          success_redirect_path:, preview_notice_label:)
      @movement_class = movement_class
      @movement_var = movement_var
      @details_attr_key = details_attr_key
      @preview_session_key = preview_session_key
      @new_path_helper = new_path_helper
      @preview_path_helper = preview_path_helper
      @success_redirect_path = success_redirect_path
      @preview_notice_label = preview_notice_label
    end
  end
end
