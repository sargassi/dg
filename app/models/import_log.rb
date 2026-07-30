class ImportLog < ApplicationRecord
  belongs_to :user

  serialize :created_ids, coder: JSON
  serialize :updated_ids, coder: JSON
  serialize :error_details, coder: JSON

  validates :status, inclusion: { in: %w[pending completed failed rolled_back cancelled] }

  def pending?
    status == 'pending'
  end

  def completed?
    status == 'completed'
  end

  def failed?
    status == 'failed'
  end

  def rolled_back?
    status == 'rolled_back'
  end
end
