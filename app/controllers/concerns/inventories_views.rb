module InventoriesViews
  extend ActiveSupport::Concern

  included do
    before_action :prepend_inventories_view_prefix

    def prepend_inventories_view_prefix
      lookup_context.prefixes = ["inventories"] | lookup_context.prefixes
    end
  end
end
