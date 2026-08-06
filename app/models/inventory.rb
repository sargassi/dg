class Inventory < ApplicationRecord
  belongs_to :warehouse
  belongs_to :location, optional: true
  belongs_to :operationtype
  belongs_to :itemin, foreign_key: :itemins_id, optional: true
  belongs_to :itemout, foreign_key: :itemouts_id, optional: true
  belongs_to :itemmovement, optional: true

  validates :gencode, presence: true
  validates :qtyavailable, numericality: true
  validates :warehouse_id, presence: true
  validate :single_movement_origin

  private

  def single_movement_origin
    origins = [itemins_id, itemouts_id, itemmovement_id].compact
    errors.add(:base, "Un inventario può riferirsi a un solo movimento") if origins.size > 1
  end
end
