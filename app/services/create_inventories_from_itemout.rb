class CreateInventoriesFromItemout
  def call(itemout)
    InventoryCreator.new.call(itemout)
  end
end
