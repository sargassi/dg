class CreateInventoriesFromItemin
  def call(itemin)
    InventoryCreator.new.call(itemin)
  end
end
