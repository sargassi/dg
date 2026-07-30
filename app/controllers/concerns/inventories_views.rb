module InventoriesViews
  extend ActiveSupport::Concern

  included do
    before_action do
      lookup_context.prefixes.unshift("inventories")
    end
  end
end
