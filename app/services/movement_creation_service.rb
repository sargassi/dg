class MovementCreationService
  Result = Struct.new(:success, :movement, :error, keyword_init: true)

  def initialize(movement_class, params, defaults: {})
    @movement_class = movement_class
    @params = params
    @defaults = defaults
  end

  def call
    movement = MovementBuilder.new(@movement_class, @params, defaults: @defaults).build
    return Result.new(success: false, movement: movement) unless movement.valid?

    ActiveRecord::Base.transaction do
      movement.save!
      InventoryCreator.new.call(movement)
    end

    Result.new(success: true, movement: movement)
  rescue => e
    Result.new(success: false, movement: movement, error: e.message)
  end
end
