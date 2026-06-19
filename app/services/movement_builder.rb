class MovementBuilder
  DETAIL_ASSOCIATIONS = {
    Itemin        => :itemins_details,
    Itemout       => :itemouts_details,
    Itemmovement  => :itemmovements_details
  }.freeze

  DEFAULT_OPERATION = {
    Itemin        => 1,
    Itemout       => 2,
    Itemmovement  => nil
  }.freeze

  def self.filter_details(movement_class, raw_params, defaults: {})
    new(movement_class, raw_params, defaults: defaults).send(:build_details)
  end

  def initialize(movement_class, params, defaults: {})
    @movement_class = movement_class
    @details_assoc   = DETAIL_ASSOCIATIONS.fetch(movement_class)
    @params          = params
    @defaults        = defaults
  end

  def build
    movement = @movement_class.new(header_params)
    build_details.each { |d| movement.send(@details_assoc).build(d) }
    movement
  end

  private

  def header_params
    @params.to_unsafe_h.except(
      :details_attributes,
      :itemins_details_attributes,
      :itemouts_details_attributes,
      :itemmovements_details_attributes
    )
  end

  def build_details
    details_attr_key = detect_details_key
    return [] unless details_attr_key

    (@params.to_unsafe_h[details_attr_key.to_s]&.values || [])
      .reject { |d| d["_destroy"] == "1" || d[:_destroy] == "1" }
      .reject { |d| d["itemcode"].blank? && d["item_id"].blank? &&
                     d[:itemcode].blank?  && d[:item_id].blank? }
      .map { |d| d.symbolize_keys.except(:_destroy, "_destroy") }
      .map { |d| apply_defaults(d) }
  end

  def detect_details_key
    [:details_attributes, :itemins_details_attributes,
     :itemouts_details_attributes, :itemmovements_details_attributes].each do |key|
      return key if @params[key].present?
    end
    nil
  end

  def apply_defaults(detail)
    detail[:collection_id]   ||= @defaults[:collection_id]   if @defaults[:collection_id].present?
    detail[:warehouse_id]    ||= @defaults[:warehouse_id]    if @defaults[:warehouse_id].present?
    detail[:location_id]     ||= @defaults[:location_id]     if @defaults[:location_id].present?
    detail[:operationtype_id] ||= DEFAULT_OPERATION[@movement_class]
    detail
  end
end
