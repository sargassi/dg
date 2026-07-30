module MovementValidations
  extend ActiveSupport::Concern

  included do
    validate :at_least_one_detail
  end

  private

  def at_least_one_detail
    assoc = self.class::DETAILS_ASSOC
    if send(assoc).reject(&:marked_for_destruction?).empty?
      errors.add(:base, "Deve esserci almeno un dettaglio")
    end
  end
end
