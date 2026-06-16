class BackfillOperationtypeOnItemmovementsDetails < ActiveRecord::Migration[7.2]
  def up
    ItemmovementsDetail.where(operationtype_id: nil).update_all(operationtype_id: 3)
  end

  def down
  end
end
